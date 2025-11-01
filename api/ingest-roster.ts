import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';

// Types
interface IngestRosterRequest {
  venueId: string;
  fileUrl: string;
  weekHint?: string; // ISO date string for Monday of the week
}

interface CanonicalShift {
  employee_name: string;
  role?: string;
  date: string; // ISO date (YYYY-MM-DD)
  start_time: string; // HH:mm
  end_time: string; // HH:mm
  break_min?: number;
  notes?: string;
}

interface IngestRosterResponse {
  success: boolean;
  rosterId?: string;
  version?: number;
  stats?: {
    inserted: number;
    changed: number;
    unchanged: number;
    unmatchedCount: number;
  };
  unmatchedNames?: string[];
  error?: string;
}

// Initialize clients
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!, // Use service key for admin access
);

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY!,
});

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

/**
 * Main handler for roster ingestion
 */
export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
): Promise<void> {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(200).json({});
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { venueId, fileUrl, weekHint }: IngestRosterRequest = req.body;

    // Validate input
    if (!venueId || !fileUrl) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: venueId, fileUrl'
      });
      return;
    }

    console.log(`[Ingest] Processing roster for venue ${venueId}`);

    // Step 1: Download file (fileUrl should be Supabase Storage URL)
    const fileData = await downloadFile(fileUrl);

    // Step 2: Extract roster data using OpenAI Vision
    console.log('[Ingest] Extracting cells from image...');
    const rawCells = await extractCellsFromImage(fileData, fileUrl);

    // Step 3: Normalize to canonical format
    console.log('[Ingest] Normalizing to canonical format...');
    const canonicalShifts = await normalizeToCanonicalFormat(rawCells, weekHint);

    console.log(`[Ingest] Extracted ${canonicalShifts.length} shifts`);

    // Step 4: Match employee names
    console.log('[Ingest] Matching employee names...');
    const { matched, unmatched } = await matchEmployeeNames(venueId, canonicalShifts);

    console.log(`[Ingest] Matched ${matched.length} shifts, ${unmatched.length} unmatched`);

    // Step 5: Determine week start date
    const weekStartDate = weekHint
      ? new Date(weekHint)
      : getMonday(new Date(canonicalShifts[0]?.date || new Date()));

    // Step 6: Create or update roster
    const { data: roster, error: rosterError } = await supabase
      .from('rosters')
      .insert({
        venue_id: venueId,
        week_start_date: weekStartDate.toISOString().split('T')[0],
        source_file_url: fileUrl,
        status: 'draft',
        uploaded_by: req.headers.authorization?.split('Bearer ')[1], // Get from auth header
        metadata: {
          total_shifts: canonicalShifts.length,
          matched_shifts: matched.length,
          unmatched_shifts: unmatched.length,
        },
      })
      .select()
      .single();

    if (rosterError) {
      throw new Error(`Failed to create roster: ${rosterError.message}`);
    }

    console.log(`[Ingest] Created roster ${roster.id} v${roster.version}`);

    // Step 7: Insert matched shifts
    if (matched.length > 0) {
      const shiftsToInsert = matched.map((shift) => ({
        roster_id: roster.id,
        user_id: shift.userId,
        venue_id: venueId,
        start_time: `${shift.date}T${shift.start_time}:00`,
        end_time: `${shift.date}T${shift.end_time}:00`,
        break_minutes: shift.break_min || 0,
        role_tag: shift.role,
        notes: shift.notes,
        original_name: shift.employee_name,
        match_confidence: shift.confidence,
        manually_matched: false,
      }));

      const { error: shiftsError } = await supabase
        .from('shifts')
        .insert(shiftsToInsert);

      if (shiftsError) {
        throw new Error(`Failed to insert shifts: ${shiftsError.message}`);
      }
    }

    // Step 8: Check for previous version and compute diff
    let stats = {
      inserted: matched.length,
      changed: 0,
      unchanged: 0,
      unmatchedCount: unmatched.length,
    };

    if (roster.version > 1) {
      console.log('[Ingest] Computing diff with previous version...');
      stats = await computeDiff(venueId, roster.id, weekStartDate);
    }

    // Step 9: Return response
    const response: IngestRosterResponse = {
      success: true,
      rosterId: roster.id,
      version: roster.version,
      stats,
      unmatchedNames: unmatched.map(s => s.employee_name),
    };

    res.setHeader('Content-Type', 'application/json');
    Object.entries(corsHeaders).forEach(([key, value]) => {
      res.setHeader(key, value);
    });

    res.status(200).json(response);

  } catch (error: any) {
    console.error('[Ingest] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Internal server error',
    });
  }
}

/**
 * Download file from URL
 */
async function downloadFile(url: string): Promise<Buffer> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download file: ${response.statusText}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Step 1: Extract cells from image using OpenAI Vision
 */
async function extractCellsFromImage(
  imageData: Buffer,
  fileUrl: string,
): Promise<{ columns: string[]; rows: Array<Record<string, string>> }> {
  const base64Image = imageData.toString('base64');

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      {
        role: 'system',
        content: `You are extracting roster tables from screenshots or PDFs. Output structured cells with row/column labels before any interpretation.

The roster is a weekly schedule.
Capture header dates, per-employee rows, start/end times, breaks, role/notes.
Return JSON with { columns: string[], rows: Array<Record<string,string>> }.
Do not guess missing cells; leave blank strings.`,
      },
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: 'Extract the roster table from this image. Identify columns (dates, times, roles) and rows (employees).',
          },
          {
            type: 'image_url',
            image_url: {
              url: fileUrl.startsWith('http')
                ? fileUrl
                : `data:image/jpeg;base64,${base64Image}`,
            },
          },
        ],
      },
    ],
    max_tokens: 4000,
    response_format: { type: 'json_object' },
  });

  const content = response.choices[0].message.content;
  if (!content) {
    throw new Error('No response from OpenAI Vision');
  }

  return JSON.parse(content);
}

/**
 * Step 2: Normalize cells to canonical shift format using function calling
 */
async function normalizeToCanonicalFormat(
  rawCells: { columns: string[]; rows: Array<Record<string, string>> },
  weekHint?: string,
): Promise<CanonicalShift[]> {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      {
        role: 'system',
        content: `Convert noisy roster cells into CanonicalShift[].
Resolve day labels like "Mon 27/10" to ISO date (use weekHint if present).
Normalise times ("9", "9am", "0900") → "09:00".
If a cell contains "OFF" or "AL", skip or map to leave (flag separately).`,
      },
      {
        role: 'user',
        content: `Raw roster data:\n${JSON.stringify(rawCells, null, 2)}\n\nWeek hint: ${weekHint || 'Current week'}`,
      },
    ],
    functions: [
      {
        name: 'emit_shifts',
        description: 'Return canonical list of shifts',
        parameters: {
          type: 'object',
          properties: {
            items: {
              type: 'array',
              items: {
                type: 'object',
                required: ['employee_name', 'date', 'start_time', 'end_time'],
                properties: {
                  employee_name: { type: 'string' },
                  role: { type: 'string' },
                  date: { type: 'string', description: 'YYYY-MM-DD' },
                  start_time: { type: 'string', description: 'HH:mm' },
                  end_time: { type: 'string', description: 'HH:mm' },
                  break_min: { type: 'number' },
                  notes: { type: 'string' },
                },
              },
            },
          },
          required: ['items'],
        },
      },
    ],
    function_call: { name: 'emit_shifts' },
  });

  const functionCall = response.choices[0].message.function_call;
  if (!functionCall) {
    throw new Error('No function call in response');
  }

  const result = JSON.parse(functionCall.arguments);
  return result.items as CanonicalShift[];
}

/**
 * Step 3: Match employee names using embeddings
 */
async function matchEmployeeNames(
  venueId: string,
  shifts: CanonicalShift[],
): Promise<{
  matched: Array<CanonicalShift & { userId: string; confidence: number }>;
  unmatched: CanonicalShift[];
}> {
  // Get all users in the venue
  const { data: venueUsers, error } = await supabase
    .from('user_venue_roles')
    .select('user_id, users!inner(id, display_name, aliases, name_embedding)')
    .eq('venue_id', venueId);

  if (error) {
    throw new Error(`Failed to fetch venue users: ${error.message}`);
  }

  const matched: Array<CanonicalShift & { userId: string; confidence: number }> = [];
  const unmatched: CanonicalShift[] = [];

  const THRESHOLD = parseFloat(process.env.VECTOR_SIM_THRESHOLD || '0.83');

  for (const shift of shifts) {
    // Create embedding for the employee name
    const embedding = await createEmbedding(shift.employee_name);

    // Find best match using cosine similarity
    let bestMatch: { userId: string; similarity: number } | null = null;

    for (const venueUser of venueUsers) {
      const user = venueUser.users;
      if (!user.name_embedding) continue;

      const similarity = cosineSimilarity(embedding, user.name_embedding);

      // Also check aliases using string distance
      const aliases = user.aliases || [];
      const stringMatch = [user.display_name, ...aliases].some(
        (name) => levenshteinDistance(shift.employee_name.toLowerCase(), name.toLowerCase()) <= 2,
      );

      const finalSimilarity = stringMatch ? Math.max(similarity, 0.9) : similarity;

      if (finalSimilarity > THRESHOLD && (!bestMatch || finalSimilarity > bestMatch.similarity)) {
        bestMatch = { userId: user.id, similarity: finalSimilarity };
      }
    }

    if (bestMatch) {
      matched.push({
        ...shift,
        userId: bestMatch.userId,
        confidence: bestMatch.similarity,
      });
    } else {
      unmatched.push(shift);
    }
  }

  return { matched, unmatched };
}

/**
 * Create embedding using OpenAI
 */
async function createEmbedding(text: string): Promise<number[]> {
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-large',
    input: text,
  });

  return response.data[0].embedding;
}

/**
 * Compute cosine similarity between two vectors
 */
function cosineSimilarity(a: number[], b: number[]): number {
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Levenshtein distance for string similarity
 */
function levenshteinDistance(str1: string, str2: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1,
        );
      }
    }
  }

  return matrix[str2.length][str1.length];
}

/**
 * Get Monday of the week containing the given date
 */
function getMonday(date: Date): Date {
  const day = date.getDay();
  const diff = date.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
  return new Date(date.setDate(diff));
}

/**
 * Compute diff between current roster and previous version
 */
async function computeDiff(
  venueId: string,
  currentRosterId: string,
  weekStartDate: Date,
): Promise<{ inserted: number; changed: number; unchanged: number; unmatchedCount: number }> {
  // Get previous version
  const { data: currentRoster } = await supabase
    .from('rosters')
    .select('version')
    .eq('id', currentRosterId)
    .single();

  const { data: prevRoster } = await supabase
    .from('rosters')
    .select('id')
    .eq('venue_id', venueId)
    .eq('week_start_date', weekStartDate.toISOString().split('T')[0])
    .eq('version', currentRoster!.version - 1)
    .maybeSingle();

  if (!prevRoster) {
    // No previous version, all shifts are new
    const { count } = await supabase
      .from('shifts')
      .select('*', { count: 'exact', head: true })
      .eq('roster_id', currentRosterId);

    return {
      inserted: count || 0,
      changed: 0,
      unchanged: 0,
      unmatchedCount: 0,
    };
  }

  // Compare shifts (simplified - in production, use more sophisticated diff)
  // TODO: Implement full diff logic with shift_changes table

  return {
    inserted: 0,
    changed: 0,
    unchanged: 0,
    unmatchedCount: 0,
  };
}
