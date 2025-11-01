import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';

// Initialize clients
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!,
);

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY!,
});

interface ShiftChange {
  userId: string;
  userName: string;
  oldShifts: Array<{
    date: string;
    start: string;
    end: string;
    role?: string;
  }>;
  newShifts: Array<{
    date: string;
    start: string;
    end: string;
    role?: string;
  }>;
}

/**
 * Notification worker - processes shift changes and sends notifications
 * Can be triggered by:
 * 1. Cron job (every 5-10 minutes)
 * 2. Manual trigger after roster publish
 * 3. Webhook from Supabase
 */
export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
): Promise<void> {
  try {
    console.log('[NotificationWorker] Starting...');

    // Step 1: Get unnotified shift changes (last 10 minutes)
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

    const { data: changes, error: changesError } = await supabase
      .from('shift_changes')
      .select(`
        id,
        user_id,
        change_type,
        old_shift_id,
        new_shift_id,
        venue_id,
        users!inner(display_name, email)
      `)
      .is('notified_at', null)
      .gte('created_at', tenMinutesAgo.toISOString());

    if (changesError) {
      throw new Error(`Failed to fetch shift changes: ${changesError.message}`);
    }

    if (!changes || changes.length === 0) {
      console.log('[NotificationWorker] No new changes to process');
      res.status(200).json({ processed: 0, message: 'No changes to process' });
      return;
    }

    console.log(`[NotificationWorker] Processing ${changes.length} changes`);

    // Step 2: Group changes by user
    const changesByUser = new Map<string, typeof changes>();

    changes.forEach((change) => {
      const existing = changesByUser.get(change.user_id) || [];
      existing.push(change);
      changesByUser.set(change.user_id, existing);
    });

    // Step 3: Process each user's changes
    let processed = 0;

    for (const [userId, userChanges] of changesByUser.entries()) {
      try {
        await processUserChanges(userId, userChanges);
        processed += userChanges.length;
      } catch (error) {
        console.error(`[NotificationWorker] Failed to process user ${userId}:`, error);
      }
    }

    // Step 4: Process scheduled reminders
    await processScheduledReminders();

    res.status(200).json({
      processed,
      message: `Processed ${processed} shift change notifications`,
    });

  } catch (error: any) {
    console.error('[NotificationWorker] Error:', error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * Process shift changes for a single user
 */
async function processUserChanges(
  userId: string,
  changes: any[],
): Promise<void> {
  console.log(`[NotificationWorker] Processing ${changes.length} changes for user ${userId}`);

  // Get user details
  const { data: user } = await supabase
    .from('users')
    .select('display_name, email, notification_preferences')
    .eq('id', userId)
    .single();

  if (!user) {
    console.error(`[NotificationWorker] User ${userId} not found`);
    return;
  }

  // Check notification preferences
  const prefs = user.notification_preferences || {};
  if (!prefs.push_enabled && !prefs.email_enabled) {
    console.log(`[NotificationWorker] User ${userId} has notifications disabled`);
    return;
  }

  // Build old vs new shift summary
  const oldShifts: any[] = [];
  const newShifts: any[] = [];

  for (const change of changes) {
    if (change.old_shift_id) {
      const { data: oldShift } = await supabase
        .from('shifts')
        .select('start_time, end_time, role_tag')
        .eq('id', change.old_shift_id)
        .single();

      if (oldShift) {
        oldShifts.push({
          date: oldShift.start_time.split('T')[0],
          start: oldShift.start_time.split('T')[1].substring(0, 5),
          end: oldShift.end_time.split('T')[1].substring(0, 5),
          role: oldShift.role_tag,
        });
      }
    }

    if (change.new_shift_id) {
      const { data: newShift } = await supabase
        .from('shifts')
        .select('start_time, end_time, role_tag')
        .eq('id', change.new_shift_id)
        .single();

      if (newShift) {
        newShifts.push({
          date: newShift.start_time.split('T')[0],
          start: newShift.start_time.split('T')[1].substring(0, 5),
          end: newShift.end_time.split('T')[1].substring(0, 5),
          role: newShift.role_tag,
        });
      }
    }
  }

  // Generate notification copy using AI
  const { title, body } = await generateNotificationCopy({
    userId,
    userName: user.display_name,
    oldShifts,
    newShifts,
  });

  // Send notification
  if (prefs.push_enabled) {
    await sendPushNotification(userId, title, body);
  }

  // Mark changes as notified
  const changeIds = changes.map(c => c.id);
  await supabase
    .from('shift_changes')
    .update({ notified_at: new Date().toISOString() })
    .in('id', changeIds);

  // Log notification
  await supabase.from('notification_log').insert({
    user_id: userId,
    notification_type: 'shift_change',
    title,
    body,
    sent_via: 'push',
    delivery_status: 'sent',
  });

  console.log(`[NotificationWorker] Sent notification to user ${userId}`);
}

/**
 * Generate notification copy using OpenAI
 */
async function generateNotificationCopy(
  context: ShiftChange,
): Promise<{ title: string; body: string }> {
  const prompt = `Context:
- Employee: ${context.userName}
- Old shifts: ${JSON.stringify(context.oldShifts)}
- New shifts: ${JSON.stringify(context.newShifts)}
- Timezone: Australia/Sydney

Write: One short push title (max 50 chars) + one-line body (max 150 chars). If multiple changes, summarise count and next shift time. Avoid jargon.

Example outputs:
- Title: "Your roster has been updated"
  Body: "3 shifts changed. Next shift: Tue 9am-5pm"

- Title: "New shift added"
  Body: "Thu 5pm-10pm as Server. Check your roster."

- Title: "Shift time changed"
  Body: "Wed now starts at 8am (was 9am)"`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: 'Generate concise, friendly notifications for staff about shift changes.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    max_tokens: 150,
    temperature: 0.7,
  });

  const content = response.choices[0].message.content || '';

  // Parse title and body (expecting format "Title: ...\nBody: ...")
  const lines = content.split('\n').filter(l => l.trim());
  const titleLine = lines.find(l => l.toLowerCase().startsWith('title:')) || '';
  const bodyLine = lines.find(l => l.toLowerCase().startsWith('body:')) || '';

  return {
    title: titleLine.replace(/^title:\s*/i, '').replace(/"/g, '').trim() || 'Roster Updated',
    body: bodyLine.replace(/^body:\s*/i, '').replace(/"/g, '').trim() || 'Your roster has changed',
  };
}

/**
 * Send push notification to user
 */
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
): Promise<void> {
  // Get user's device tokens
  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token, platform')
    .eq('user_id', userId);

  if (!tokens || tokens.length === 0) {
    console.log(`[NotificationWorker] No device tokens for user ${userId}`);
    return;
  }

  // TODO: Implement FCM push notification sending
  // For now, log the notification
  console.log(`[NotificationWorker] Would send to ${tokens.length} devices:`, {
    title,
    body,
    tokens: tokens.map(t => `${t.platform}:${t.token.substring(0, 10)}...`),
  });

  // Example FCM implementation:
  // const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY;
  // for (const token of tokens) {
  //   await fetch('https://fcm.googleapis.com/fcm/send', {
  //     method: 'POST',
  //     headers: {
  //       'Authorization': `key=${FCM_SERVER_KEY}`,
  //       'Content-Type': 'application/json',
  //     },
  //     body: JSON.stringify({
  //       to: token.token,
  //       notification: { title, body },
  //       priority: 'high',
  //     }),
  //   });
  // }
}

/**
 * Process scheduled reminders
 */
async function processScheduledReminders(): Promise<void> {
  console.log('[NotificationWorker] Processing scheduled reminders...');

  // Get upcoming shifts (next 24 hours)
  const now = new Date();
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const { data: upcomingShifts } = await supabase
    .from('shifts')
    .select(`
      id,
      user_id,
      start_time,
      end_time,
      role_tag,
      venues!inner(name, timezone)
    `)
    .gte('start_time', now.toISOString())
    .lte('start_time', tomorrow.toISOString())
    .eq('rosters.status', 'published');

  if (!upcomingShifts || upcomingShifts.length === 0) {
    console.log('[NotificationWorker] No upcoming shifts in next 24h');
    return;
  }

  console.log(`[NotificationWorker] Found ${upcomingShifts.length} upcoming shifts`);

  // For each shift, check notification rules
  for (const shift of upcomingShifts) {
    const { data: rules } = await supabase
      .from('notification_rules')
      .select('offsets')
      .eq('user_id', shift.user_id)
      .eq('rule_type', 'shift_reminder')
      .eq('enabled', true)
      .maybeSingle();

    if (!rules || !rules.offsets) continue;

    // Check if any offset matches current time
    // Offsets format: ["-1d@09:00", "-5h", "-2h"]
    // TODO: Implement offset calculation and reminder scheduling

    console.log(`[NotificationWorker] Shift ${shift.id} has reminder rules:`, rules.offsets);
  }
}
