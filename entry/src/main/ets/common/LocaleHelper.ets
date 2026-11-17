import { AppState } from '../services/AppState';
import { LANG_ZH } from '../models/AppTypes';

export function t(key: string, langOverride?: number): string {
  const language: number = langOverride !== undefined
    ? langOverride
    : (AppState.getInstance().settings.language ?? 0);
  if (language === LANG_ZH) {
    return zh(key);
  }
  return en(key);
}

function en(key: string): string {
  switch (key) {
    case 'app_title':
      return 'FocusAnchor';
    case 'app_tagline':
      return 'Neurodiversity-friendly focus companion';
    case 'tab_home':
      return 'Home';
    case 'tab_heart':
      return 'Heart';
    case 'tab_tasks':
      return 'Tasks';
    case 'tab_insights':
      return 'Insights';
    case 'settings_title':
      return 'Settings';
    case 'section_language':
      return 'Language';
    case 'section_profile':
      return 'Profile';
    case 'section_privacy':
      return 'Privacy';
    case 'section_heart':
      return 'Heart-rate & security';
    case 'label_name':
      return 'Display name';
    case 'label_age':
      return 'Age';
    case 'label_avatar':
      return 'Avatar';
    case 'label_language':
      return 'App language';
    case 'label_hr_range':
      return 'Heart-rate range';
    case 'label_pin':
      return 'PIN lock';
    case 'privacy_share':
      return 'Share anonymised usage data';
    case 'privacy_analytics':
      return 'Allow local analytics';
    case 'privacy_show_age':
      return 'Show age on profile';
    case 'privacy_local_only':
      return 'Keep data encrypted on device only';
    case 'btn_save':
      return 'Save';
    case 'btn_back':
      return 'Back';
    case 'btn_cancel':
      return 'Cancel';
    case 'btn_add_task':
      return 'Add';
    case 'btn_start_monitor':
      return 'Start';
    case 'btn_stop_monitor':
      return 'Stop';
    case 'btn_record':
      return 'Record';
    case 'btn_done':
      return 'Done';
    case 'btn_undo':
      return 'Undo';
    case 'btn_remove':
      return 'Remove';
    case 'lang_en':
      return 'EN';
    case 'lang_zh':
      return '中文';
    case 'saved':
      return 'Settings saved';
    case 'placeholder_name':
      return 'Your name';
    case 'placeholder_age':
      return 'Age';
    case 'placeholder_pin':
      return '4-digit PIN';
    case 'privacy_hint':
      return 'Privacy choices stay on this device and can be changed anytime.';
    case 'profile_hint':
      return 'Tell FocusAnchor who you are so guidance can stay personal and gentle.';
    case 'btn_pick_album':
      return 'From album';
    case 'pick_album_fail':
      return 'Unable to open album';
    case 'metric_heart_rate':
      return 'Heart rate';
    case 'metric_efficiency':
      return 'Efficiency';
    case 'metric_efficiency_hint':
      return '0-100 score';
    case 'metric_focus_status':
      return 'Focus status';
    case 'focus_calm':
      return 'Calm focus';
    case 'focus_alert':
      return 'Attention needed';
    case 'focus_hint_default':
      return 'Start heart monitoring to receive guidance.';
    case 'latest_guidance':
      return 'Latest guidance';
    case 'zone_waiting':
      return 'waiting';
    case 'zone_low':
      return 'low';
    case 'zone_optimal':
      return 'optimal';
    case 'zone_high':
      return 'high';
    case 'zone_unknown':
      return 'unknown';
    case 'current_bpm':
      return 'Current BPM';
    case 'target_bpm':
      return 'Target';
    case 'hr_alert_title':
      return 'Heart-rate alert';
    case 'hr_alert_ok':
      return 'Acknowledged';
    case 'manual_bpm':
      return 'Manual BPM';
    case 'recent_readings':
      return 'Recent readings';
    case 'study_tasks':
      return 'Study tasks';
    case 'task_title':
      return 'Task title';
    case 'learning_content':
      return 'Learning content';
    case 'minutes':
      return 'Minutes';
    case 'priority_high':
      return 'High';
    case 'priority_medium':
      return 'Med';
    case 'priority_low':
      return 'Low';
    case 'min_unit':
      return 'min';
    case 'efficiency_index':
      return 'Learning efficiency index';
    case 'efficiency_hint':
      return 'Combines heart-rate zone, completion rate, and priority balance.';
    case 'personal_suggestions':
      return 'Personalised suggestions';
    case 'hr_msg_optimal':
      return 'Heart rate is within your focus range.';
    case 'hr_msg_low':
      return 'Heart rate is below your range. Consider a short walk or hydration break.';
    case 'hr_msg_high':
      return 'Heart rate is above your range. Try a breathing pause before continuing.';
    case 'advice_high_title':
      return 'Regulate before studying';
    case 'advice_high_detail':
      return 'Use a 4-7-8 breathing cycle for one minute, then restart with a 10-minute micro task.';
    case 'advice_low_title':
      return 'Activate gently';
    case 'advice_low_detail':
      return 'Stand up, stretch, and pick one low-friction task to rebuild momentum.';
    case 'advice_ok_title':
      return 'You are in a steady focus zone';
    case 'advice_ok_detail':
      return 'Keep one task visible, silence notifications, and use a 25-minute focus window.';
    case 'advice_next_title':
      return 'Next priority task';
    case 'advice_empty_title':
      return 'Capture your next step';
    case 'advice_empty_detail':
      return 'Add one concrete study task so FocusAnchor can guide your next micro action.';
    case 'advice_rate_title':
      return 'Completion rate';
    case 'advice_rate_detail_prefix':
      return '';
    case 'advice_rate_detail_suffix':
      return '% of tasks completed. Break large goals into 15-minute units.';
    case 'method_reading':
      return 'reading';
    case 'method_practice':
      return 'practice';
    case 'method_review':
      return 'review';
    case 'method_discussion':
      return 'discussion';
    case 'method_other':
      return 'other';
    case 'placeholder_hr_min':
      return 'Min BPM';
    case 'placeholder_hr_max':
      return 'Max BPM';
    case 'bpm_unit':
      return 'bpm';
    case 'btn_focus':
      return 'Focus';
    case 'system_time':
      return 'System time';
    case 'focus_level_green':
      return 'excellent';
    case 'focus_level_yellow':
      return 'good';
    case 'focus_level_orange':
      return 'fair';
    case 'focus_level_red':
      return 'poor';
    case 'btn_voice':
      return 'Voice';
    case 'btn_voice_add':
      return 'Voice+';
    case 'voice_listening':
      return 'Listening…';
    case 'voice_ok':
      return 'Voice captured';
    case 'voice_fail':
      return 'Mic denied';
    case 'task_saved_view':
      return 'Saved. See list below.';
    case 'btn_xiaoyi_advice':
      return 'Advice';
    case 'insight_label':
      return 'Advice';
    case 'due_time':
      return 'Deadline (YYYY-MM-DD HH:mm)';
    case 'edit_task':
      return 'Edit task';
    case 'pending_list':
      return 'Pending';
    case 'pending_empty':
      return 'No pending tasks. Add one above.';
    case 'deadline_label':
      return 'Deadline';
    case 'btn_clear':
      return 'Clear';
    case 'priority_auto':
      return 'Raised near deadline';
    case 'selected_task':
      return 'Selected task';
    case 'reminder_title':
      return 'FocusAnchor reminder';
    case 'reminder_body_prefix':
      return 'You still have ';
    case 'reminder_body_suffix':
      return ' unfinished task(s).';
    case 'btn_remind':
      return 'Remind';
    case 'xiaoyi_hr_hint':
      return 'Heart rate via Xiaoyi';
    case 'float_menu_title':
      return 'Quick';
    case 'float_voice':
      return 'Voice';
    case 'float_listening':
      return 'Listening…';
    case 'float_voice_unknown':
      return 'Say Focus / Settings / Add task';
    case 'float_task_ok':
      return 'Task added';
    case 'float_double_hint':
      return 'Double-tap ball for voice';
    case 'float_voice_tip':
      return 'Say Focus, Settings, or Add task';
    case 'float_voice_retry':
      return 'Speak again';
    case 'hr_msg_yellow':
      return 'Heart rate slightly elevated. Stay mindful.';
    case 'hr_msg_orange':
      return 'Heart rate rising. Consider a short pause.';
    case 'wear_readonly':
      return 'Watch sync (read-only from phone)';
    case 'home_overview':
      return 'Overview';
    default:
      return key;
  }
}

function zh(key: string): string {
  switch (key) {
    case 'app_title':
      return '焦点锚';
    case 'app_tagline':
      return '面向神经多样性友好的专注伙伴';
    case 'tab_home':
      return '首页';
    case 'tab_heart':
      return '心率';
    case 'tab_tasks':
      return '任务';
    case 'tab_insights':
      return '建议';
    case 'settings_title':
      return '设置';
    case 'section_language':
      return '语言';
    case 'section_profile':
      return '个人信息';
    case 'section_privacy':
      return '隐私设置';
    case 'section_heart':
      return '心率与安全';
    case 'label_name':
      return '名称';
    case 'label_age':
      return '年龄';
    case 'label_avatar':
      return '头像';
    case 'label_language':
      return '应用语言';
    case 'label_hr_range':
      return '心率区间';
    case 'label_pin':
      return 'PIN 锁定';
    case 'privacy_share':
      return '分享匿名使用数据';
    case 'privacy_analytics':
      return '允许本地分析';
    case 'privacy_show_age':
      return '在个人资料中显示年龄';
    case 'privacy_local_only':
      return '数据仅本地加密存储';
    case 'btn_save':
      return '保存';
    case 'btn_back':
      return '返回';
    case 'btn_cancel':
      return '取消';
    case 'btn_add_task':
      return '添加任务';
    case 'btn_start_monitor':
      return '开始监测';
    case 'btn_stop_monitor':
      return '停止监测';
    case 'btn_record':
      return '记录';
    case 'btn_done':
      return '完成';
    case 'btn_undo':
      return '撤销';
    case 'btn_remove':
      return '删除';
    case 'lang_en':
      return '英语';
    case 'lang_zh':
      return '中文';
    case 'saved':
      return '设置已保存';
    case 'placeholder_name':
      return '你的名称';
    case 'placeholder_age':
      return '年龄';
    case 'placeholder_pin':
      return '4 位 PIN';
    case 'privacy_hint':
      return '隐私选项保存在本机，可随时修改。';
    case 'profile_hint':
      return '完善个人信息，让焦点锚给出更贴合你的温和引导。';
    case 'btn_pick_album':
      return '从相册选择';
    case 'pick_album_fail':
      return '无法打开相册';
    case 'metric_heart_rate':
      return '心率';
    case 'metric_efficiency':
      return '效率';
    case 'metric_efficiency_hint':
      return '0-100 分';
    case 'metric_focus_status':
      return '专注状态';
    case 'focus_calm':
      return '平静专注';
    case 'focus_alert':
      return '需要关注';
    case 'focus_hint_default':
      return '开始心率监测以获得引导。';
    case 'latest_guidance':
      return '最新建议';
    case 'zone_waiting':
      return '等待中';
    case 'zone_low':
      return '偏低';
    case 'zone_optimal':
      return '适宜';
    case 'zone_high':
      return '偏高';
    case 'zone_unknown':
      return '未知';
    case 'current_bpm':
      return '当前心率';
    case 'target_bpm':
      return '目标区间';
    case 'hr_alert_title':
      return '心率提醒';
    case 'hr_alert_ok':
      return '知道了';
    case 'manual_bpm':
      return '手动输入心率';
    case 'recent_readings':
      return '近期记录';
    case 'study_tasks':
      return '学习任务';
    case 'task_title':
      return '任务标题';
    case 'learning_content':
      return '学习内容';
    case 'minutes':
      return '分钟';
    case 'priority_high':
      return '高';
    case 'priority_medium':
      return '中';
    case 'priority_low':
      return '低';
    case 'min_unit':
      return '分钟';
    case 'efficiency_index':
      return '学习效率指数';
    case 'efficiency_hint':
      return '综合心率区间、完成率与优先级平衡。';
    case 'personal_suggestions':
      return '个性化建议';
    case 'hr_msg_optimal':
      return '心率处于你的专注区间内。';
    case 'hr_msg_low':
      return '心率低于设定区间。可短暂散步或补充水分。';
    case 'hr_msg_high':
      return '心率高于设定区间。建议先做一次呼吸调节再继续。';
    case 'advice_high_title':
      return '先调节再学习';
    case 'advice_high_detail':
      return '先做 1 分钟 4-7-8 呼吸，再用 10 分钟微任务重启。';
    case 'advice_low_title':
      return '温和激活';
    case 'advice_low_detail':
      return '站起来伸展一下，选一个低阻力任务重建节奏。';
    case 'advice_ok_title':
      return '你正处于稳定专注区';
    case 'advice_ok_detail':
      return '只保留一个可见任务，静音通知，使用 25 分钟专注块。';
    case 'advice_next_title':
      return '下一优先任务';
    case 'advice_empty_title':
      return '写下你的下一步';
    case 'advice_empty_detail':
      return '添加一个具体学习任务，焦点锚就能继续引导你。';
    case 'advice_rate_title':
      return '完成率';
    case 'advice_rate_detail_prefix':
      return '已完成 ';
    case 'advice_rate_detail_suffix':
      return '% 的任务。把大目标拆成 15 分钟单位。';
    case 'method_reading':
      return '阅读';
    case 'method_practice':
      return '练习';
    case 'method_review':
      return '复习';
    case 'method_discussion':
      return '讨论';
    case 'method_other':
      return '其他';
    case 'placeholder_hr_min':
      return '最低心率';
    case 'placeholder_hr_max':
      return '最高心率';
    case 'bpm_unit':
      return '次/分';
    case 'btn_focus':
      return '焦点';
    case 'system_time':
      return '系统时间';
    case 'focus_level_green':
      return '优秀';
    case 'focus_level_yellow':
      return '良好';
    case 'focus_level_orange':
      return '一般';
    case 'focus_level_red':
      return '较差';
    case 'btn_voice':
      return '小艺语音';
    case 'btn_voice_add':
      return '语音添加';
    case 'voice_listening':
      return '正在聆听，请说话…';
    case 'voice_ok':
      return '语音已识别';
    case 'voice_fail':
      return '麦克风权限被拒绝';
    case 'task_saved_view':
      return '已保存到本地，请在下方列表查看。';
    case 'btn_xiaoyi_advice':
      return '小艺建议';
    case 'insight_label':
      return '建议';
    case 'due_time':
      return 'Deadline（YYYY-MM-DD HH:mm）';
    case 'edit_task':
      return '编辑任务';
    case 'pending_list':
      return '未完成任务';
    case 'pending_empty':
      return '暂无未完成任务，在上方添加后会出现在此列表。';
    case 'deadline_label':
      return 'Deadline';
    case 'btn_clear':
      return '从列表清除';
    case 'priority_auto':
      return '临近 Deadline，紧急程度已提高一级';
    case 'selected_task':
      return '当前任务';
    case 'reminder_title':
      return '焦点锚提醒';
    case 'reminder_body_prefix':
      return '你还有 ';
    case 'reminder_body_suffix':
      return ' 个未完成任务。';
    case 'btn_remind':
      return '提醒未完成';
    case 'xiaoyi_hr_hint':
      return '经小艺智能体测量心率';
    case 'float_menu_title':
      return '快捷';
    case 'float_voice':
      return '语音';
    case 'float_listening':
      return '聆听中…';
    case 'float_voice_unknown':
      return '请说：焦点 / 设置 / 添加任务';
    case 'float_task_ok':
      return '已添加任务';
    case 'float_double_hint':
      return '双击悬浮球语音';
    case 'float_voice_tip':
      return '请说：焦点、设置或添加任务';
    case 'float_voice_retry':
      return '再试一次';
    case 'hr_msg_yellow':
      return '心率略有升高，请保持觉察。';
    case 'hr_msg_orange':
      return '心率继续升高，建议短暂暂停。';
    case 'wear_readonly':
      return '手表同步（仅从手机只读）';
    case 'home_overview':
      return '概览';
    default:
      return en(key);
  }
}

export function focusLevelLabel(level: string | undefined, langOverride?: number): string {
  if (level === 'green') {
    return t('focus_level_green', langOverride);
  }
  if (level === 'yellow') {
    return t('focus_level_yellow', langOverride);
  }
  if (level === 'orange') {
    return t('focus_level_orange', langOverride);
  }
  if (level === 'red') {
    return t('focus_level_red', langOverride);
  }
  return t('zone_waiting', langOverride);
}

export function zoneLabel(zone: string | undefined): string {
  if (zone === 'low') {
    return t('zone_low');
  }
  if (zone === 'optimal') {
    return t('zone_optimal');
  }
  if (zone === 'high') {
    return t('zone_high');
  }
  if (zone === 'unknown') {
    return t('zone_unknown');
  }
  return t('zone_waiting');
}

export function hrMessageByZone(zone: string | undefined): string {
  if (zone === 'low') {
    return t('hr_msg_low');
  }
  if (zone === 'high') {
    return t('hr_msg_high');
  }
  if (zone === 'optimal') {
    return t('hr_msg_optimal');
  }
  return t('focus_hint_default');
}

export function methodLabel(method: string): string {
  if (method === 'reading') {
    return t('method_reading');
  }
  if (method === 'practice') {
    return t('method_practice');
  }
  if (method === 'review') {
    return t('method_review');
  }
  if (method === 'discussion') {
    return t('method_discussion');
  }
  return t('method_other');
}
