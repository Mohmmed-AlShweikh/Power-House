# UI audit — Step 0

Baseline: `caa6d10f132a79fa36bcd44bcf95885d0cc5340d`. Static source audit of every Dart file under `lib/`; no application source changed in this step. Inventory includes dormant widgets, not just reachable routes. Runtime/accessibility observations below are risks from source, not claims of device testing.

## Screens and reachability

| Surface | Entry / destinations and existing behaviour to preserve |
| --- | --- |
| LoginScreen | `/login`: ID, password, visibility, submit, forgot-password guidance, registration link, provider/submit errors and busy state. Actual authentication is email/password derived from ID, despite README phone-auth description. |
| RegisterScreen | `/register`: consumer/owner selector; ID, name/generator name, address, password, confirmation; validation, submit, approval-wait success dialog, login link. |
| SetupScreen | Present in source but not registered in router: name/address save and skip; progress indicator and decorative avatar. Do not add a route or activate it. |
| ConsumerShell | `/consumer`: IndexedStack retains Home, Usage, Bills, Profile; notification stream listener unchanged. |
| HomeTab | Greeting/name/address; theme, notifications, logout; generator status/runtime/schedule; monthly consumption, amount, amperage, tariff, daily consumption, latest alerts/count. |
| UsageTab | Daily/weekly/monthly selection; total/average/maximum; daily curved line, weekly horizontal bars, monthly columns; loading and empty/error fallbacks. Preserve all underlying data/calculations. |
| BillsTab | Actionable unpaid/rejected banner; bill history and status; receipt upload/gallery picker/preview/busy/success/failure. |
| ProfileTab | Personal details/join date/role; edit name/address/phone; theme; submit complaint/history/reply; logout. Security/help sheet helpers exist but are not linked in the current settings list. Do not add access paths. |
| AlertsTab | Source-only screen; not in ConsumerShell or router: unread count, list, clear-all confirmation. Preserve its existing reachability. NotificationBell supplies the live notification sheet. |
| AdminScreen | `/admin`: six controller destinations in exact order: overview, requests, subscribers, bills, complaints, profile. Keep tab index 3 for existing bill jump. Theme/logout remain. |
| Admin overview | Generator switch with confirmation; tariff/schedule sheet and time pickers; subscriber counts, open complaints, monthly bill summary, recent activity. |
| Admin requests | Pending subscriber identity/address and accept/reject/busy/error/empty states. |
| Admin subscribers | Search by name/phone; subscriber detail push; active toggle; amperage-edit dialog. Add-sheet helpers exist without a visible caller. |
| SubscriberDetailsScreen | Imperative MaterialPageRoute: identity/contact/address/amperage/status; pending review, due and paid groups; review action pops and jumps to bills. |
| Admin bills | Add bill; five status filters; cards, review preview/dialog, accept/reject; ID lookup, editable amount, weekly kWh, calculated amount, automatic month/year. |
| Admin complaints | Text/person/time/status/reply; reply dialog resolves and notifies; empty/loading and mock error fallbacks. |
| Admin profile | Avatar/name/role/phone; subscriber/active/bill totals; contact/address/join date; edit sheet, theme, logout. |
| SuperAdminScreen | `/super_admin`: pending owner count and approval cards, accept/reject; diagnostics button with success/error dialogs; logout, debug-only information, loading/empty/error. |
| Global error view | main.dart ErrorWidget shows icon and exception; currently styled independently. |

## Dialogs, sheets and pickers — every call site

Names below are lexical owning classes (including state classes); line numbers refer to this baseline.

### lib/views/screens/admin/admin_screen.dart

- `lib/views/screens/admin/admin_screen.dart:327` — `_DashboardTab`: `showModalBottomSheet`. Context: `double currentPrice, DateTime? scheduledOnAt, DateTime? scheduledOffAt, ) { showModalBottomSheet(`
- `lib/views/screens/admin/admin_screen.dart:343` — `_DashboardTab`: `showTimePicker`. Context: `? TimeOfDay.fromDateTime(scheduledOffAt) : const TimeOfDay(hour: 20, minute: 0);  Future<void> pickTime(bool isOnTime) async { final result = await showTimePicker(`
- `lib/views/screens/admin/admin_screen.dart:632` — `_GeneratorToggleCard`: `showDialog`. Context: `).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 400.ms); }  void _confirmToggle(BuildContext context, bool v) { showDialog(`
- `lib/views/screens/admin/admin_screen.dart:1020` — `_SubscribersTabState`: `showModalBottomSheet`. Context: `); }  void _showAddSheet(BuildContext context) { showModalBottomSheet(`
- `lib/views/screens/admin/admin_screen.dart:1073` — `_SubscriberCard`: `showDialog`. Context: ` Future<void> _editAmpere(BuildContext context) async { final ctrl = TextEditingController( text: sub.ampereLimit > 0 ? '${sub.ampereLimit}' : ''); final result = await showDialog<int>(`
- `lib/views/screens/admin/admin_screen.dart:1389` — `_MockSubscribersState`: `showModalBottomSheet`. Context: `void _showAddSheet(BuildContext context) { final nameCtrl = TextEditingController(); final phoneCtrl = TextEditingController(); final addressCtrl = TextEditingController(); showModalBottomSheet(`
- `lib/views/screens/admin/admin_screen.dart:1661` — `_BillsTabState`: `showModalBottomSheet`. Context: `} }  void _showAddBillSheet(BuildContext context) { showModalBottomSheet(`
- `lib/views/screens/admin/admin_screen.dart:2218` — `_AdminBillCard`: `showDialog`. Context: `subscriberName.isNotEmpty ? subscriberName : bill.userId;  void _openReviewDialog(BuildContext context) { if (bill.status != BillStatus.pendingReview) return; showDialog(`
- `lib/views/screens/admin/admin_screen.dart:2779` — `_ComplaintCard`: `showDialog`. Context: `}  void _showReplyDialog(BuildContext context, String complaintId) { final ctrl = TextEditingController(); showDialog(`
- `lib/views/screens/admin/admin_screen.dart:2936` — `_MockComplaintCard`: `showDialog`. Context: `}  void _showMockReplyDialog(BuildContext context) { final ctrl = TextEditingController(); showDialog(`
- `lib/views/screens/admin/admin_screen.dart:3317` — `_AdminProfileTab`: `showModalBottomSheet`. Context: `final nameCtrl = TextEditingController(text: profile?.name ?? ''); final addressCtrl = TextEditingController(text: profile?.address ?? ''); final phoneCtrl = TextEditingController(text: profile?.phone ?? '');  showModalBottomSheet(`

### lib/views/screens/consumer/alerts_tab.dart

- `lib/views/screens/consumer/alerts_tab.dart:60` — `AlertsTab`: `showDialog`. Context: `: TextButton( onPressed: () async { final uid = profile?.uid; if (uid == null || uid.isEmpty) return; final confirm = await showDialog<bool>(`

### lib/views/screens/consumer/bills_tab.dart

- `lib/views/screens/consumer/bills_tab.dart:144` — `_PendingBanner`: `showModalBottomSheet`. Context: `), ), ElevatedButton( onPressed: () { showModalBottomSheet(`
- `lib/views/screens/consumer/bills_tab.dart:411` — `_BillCard`: `showModalBottomSheet`. Context: `: 'غير مدفوعة';  return GestureDetector( onTap: canUpload ? () => showModalBottomSheet(`

### lib/views/screens/consumer/profile_tab.dart

- `lib/views/screens/consumer/profile_tab.dart:182` — `ProfileTab`: `showModalBottomSheet`. Context: `final nameCtrl = TextEditingController(text: profile?.name ?? ''); final addressCtrl = TextEditingController(text: profile?.address ?? ''); final phoneCtrl = TextEditingController(text: profile?.phone ?? '');  showModalBottomSheet(`
- `lib/views/screens/consumer/profile_tab.dart:273` — `ProfileTab`: `showModalBottomSheet`. Context: `); }  void _showSecuritySheet(BuildContext context) { showModalBottomSheet(`
- `lib/views/screens/consumer/profile_tab.dart:283` — `ProfileTab`: `showModalBottomSheet`. Context: `); }  void _showHelpSheet(BuildContext context) { showModalBottomSheet(`
- `lib/views/screens/consumer/profile_tab.dart:293` — `ProfileTab`: `showModalBottomSheet`. Context: `); }  void _showComplaintSheet(BuildContext context, WidgetRef ref) { showModalBottomSheet(`
- `lib/views/screens/consumer/profile_tab.dart:307` — `ProfileTab`: `showModalBottomSheet`. Context: `}  void _showMyComplaintsSheet(BuildContext context, WidgetRef ref) { final uid = ref.read(authProvider).profile?.uid ?? ''; showModalBottomSheet(`
- `lib/views/screens/consumer/profile_tab.dart:512` — `_SecuritySheetState`: `showDialog`. Context: `final oldCtrl = TextEditingController(); final newCtrl = TextEditingController(); final confirmCtrl = TextEditingController();  final ok = await showDialog<bool>(`

### lib/views/screens/login_screen.dart

- `lib/views/screens/login_screen.dart:40` — `_LoginScreenState`: `showDialog`. Context: ` Future<void> _forgotPassword() async { final id = _idCtrl.text.trim(); if (id.isEmpty) { showDialog(`
- `lib/views/screens/login_screen.dart:62` — `_LoginScreenState`: `showDialog`. Context: `return; }  // Show informational dialog — in-app reset handled by admin showDialog(`

### lib/views/screens/register_screen.dart

- `lib/views/screens/register_screen.dart:81` — `_RegisterScreenState`: `showDialog`. Context: `} else { final msg = _role == UserRole.admin ? 'تم تقديم طلبك بنجاح.\nيُرجى انتظار موافقة المشرف العام للدخول.' : 'تم تقديم طلبك بنجاح.\nيُرجى انتظار موافقة صاحب المولد للدخول.'; await showDialog(`

### lib/views/screens/super_admin/super_admin_screen.dart

- `lib/views/screens/super_admin/super_admin_screen.dart:112` — `SuperAdminScreen`: `showDialog`. Context: `'المجموع: ${snap.size} مستند\n' 'أصحاب المولدات: ${owners.length}\n' 'بانتظار الموافقة: ${pendingOwners.length}\n' '\n--- جميع المستندين ---\n$all'; await showDialog(`
- `lib/views/screens/super_admin/super_admin_screen.dart:132` — `SuperAdminScreen`: `showDialog`. Context: `), ), ); } catch (e) { await showDialog(`

### lib/views/widgets/notification_bell.dart

- `lib/views/widgets/notification_bell.dart:66` — `NotificationBell`: `showModalBottomSheet`. Context: `Future<void> _open(BuildContext context, WidgetRef ref, String uid) async { if (uid.isNotEmpty) { FirebaseService().markAllAlertsRead(uid); } await showModalBottomSheet(`

## Reusable and local widget/painter inventory

Every class in UI files is listed, including state classes, chart data wrappers and mock/error-only components. Private duplicated cards/fields should converge on shared presentation components after identity approval.

- `lib/main.dart`: `GeneratorPortalApp`.
- `lib/views/screens/admin/admin_screen.dart`: `AdminScreen`, `_AdminScreenState`, `_DashboardTab`, `_GeneratorToggleCard`, `_StatBox`, `_RecentActivity`, `_MonthlyBillStatsCard`, `_BillStatItem`, `_SubscribersTab`, `_SubscribersTabState`, `_SubscriberCard`, `_MockSubscribers`, `_MockSubscribersState`, `_SheetField`, `_BillsTab`, `_BillsTabState`, `_FilterRow`, `_AddBillHeader`, `_AddBillSheet`, `_AddBillSheetState`, `_AdminBillCard`, `_MockAdminBillCard`, `_MockAdminBillCardState`, `_ComplaintsTab`, `_EmptyComplaints`, `_ComplaintCard`, `_MockComplaintCard`, `_AdminProfileTab`, `_PendingUsersTab`, `_PendingUserCard`, `_PendingUserCardState`, `_MockPendingUsers`, `_MockPendingUsersState`, `_SectionLabel`, `_PRow`, `_ProfileStatChip`, `_InfoTile`, `_ActionTile`, `_Separator`.
- `lib/views/screens/admin/subscriber_details_screen.dart`: `SubscriberDetailsScreen`, `_SubInfoCard`, `_SectionHeader`, `_PaymentRequestCard`, `_BillInfoCard`, `_EmptyBills`, `ReceiptReviewDialog`, `_ReceiptReviewDialogState`.
- `lib/views/screens/consumer/alerts_tab.dart`: `AlertsTab`, `_EmptyAlerts`, `_AlertCard`, `_MockAlerts`.
- `lib/views/screens/consumer/bills_tab.dart`: `BillsTab`, `_PendingBanner`, `_PendingBannerSkeleton`, `_UploadReceiptSheet`, `_UploadReceiptSheetState`, `_EmptyBills`, `_BillCard`, `_MockBills`.
- `lib/views/screens/consumer/consumer_shell.dart`: `ConsumerShell`, `_ConsumerShellState`.
- `lib/views/screens/consumer/home_tab.dart`: `HomeTab`, `_GeneratorStatusCard`, `_StatCard`, `_AlertItem`.
- `lib/views/screens/consumer/profile_tab.dart`: `ProfileTab`, `_SheetField`, `_InfoCard`, `_InfoRow`, `_SettingsGroup`, `_SecuritySheet`, `_SecuritySheetState`, `_SecurityTile`, `_HelpSheet`, `_HelpTile`, `_SettingsItem`, `_ThemeToggleCard`, `_LogoutButton`, `_ComplaintSheet`, `_ComplaintSheetState`, `_MyComplaintsSheet`, `_ConsumerComplaintCard`.
- `lib/views/screens/consumer/usage_tab.dart`: `UsageTab`, `_UsageTabState`, `_UsageBody`, `_HeaderStat`, `_PillButton`, `_DataPoint`, `_LineChart`, `_LinePainter`, `_HorizontalBarChart`, `_VerticalBarChart`, `_EmptyUsage`.
- `lib/views/screens/login_screen.dart`: `LoginScreen`, `_LoginScreenState`, `_Card`, `_Label`.
- `lib/views/screens/register_screen.dart`: `RegisterScreen`, `_RegisterScreenState`, `_SectionLabel`, `_RoleSwitch`, `_RoleTab`, `_Field`, `_PasswordField`.
- `lib/views/screens/setup_screen.dart`: `SetupScreen`, `_SetupScreenState`, `_ProgressBar`, `_StepDot`, `_Line`, `_Card`, `_AvatarPicker`, `_Label`, `_Field`.
- `lib/views/screens/super_admin/super_admin_screen.dart`: `SuperAdminScreen`, `_StatChip`, `_OwnerRequestCard`, `_OwnerRequestCardState`, `_EmptyState`, `_SuperAdminErrorState`, `_MockOwnersList`, `_MockOwnersListState`.
- `lib/views/widgets/base64_image_viewer.dart`: `Base64ImageViewer`, `_ErrorBox`.
- `lib/views/widgets/notification_bell.dart`: `NotificationBell`, `_NotificationsSheet`, `_EmptyState`, `_SheetAlertCard`.

## Hardcoded styling inventory

Counts include definitions, not runtime instances. Named `Colors.*` and AppColors constants are used extensively in addition to literal hex colors. Sizes remain scattered across padding, radius, chart and dialog definitions.

| File | Literal hex colors | TextStyle constructors | Explicit font sizes (sp) |
| --- | ---: | ---: | --- |
| `lib/config/colors.dart` | 21 | 0 | — |
| `lib/main.dart` | 0 | 1 | 14 |
| `lib/providers/data_provider.dart` | 3 | 0 | — |
| `lib/providers/theme_provider.dart` | 0 | 18 | 13, 15, 16, 18, 22, 28 |
| `lib/views/screens/admin/admin_screen.dart` | 8 | 118 | 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 28 |
| `lib/views/screens/admin/subscriber_details_screen.dart` | 0 | 21 | 11, 12, 13, 14, 15, 17, 22 |
| `lib/views/screens/consumer/alerts_tab.dart` | 0 | 9 | 11, 12, 13, 14, 15 |
| `lib/views/screens/consumer/bills_tab.dart` | 2 | 13 | 11, 12, 13, 14, 15, 16 |
| `lib/views/screens/consumer/consumer_shell.dart` | 1 | 2 | 11 |
| `lib/views/screens/consumer/home_tab.dart` | 6 | 15 | 11, 12, 13, 14, 17, 20, 22 |
| `lib/views/screens/consumer/profile_tab.dart` | 0 | 34 | 11, 12, 13, 14, 15, 18, 32 |
| `lib/views/screens/consumer/usage_tab.dart` | 0 | 15 | 9, 10, 11, 12, 13, 14, 15, 34 |
| `lib/views/screens/login_screen.dart` | 0 | 13 | 12, 13, 14, 16, 17, 18, 22 |
| `lib/views/screens/register_screen.dart` | 0 | 14 | 13, 14, 15, 18, 20, 22 |
| `lib/views/screens/setup_screen.dart` | 0 | 3 | 12, 15 |
| `lib/views/screens/super_admin/super_admin_screen.dart` | 2 | 22 | 11, 12, 13, 14, 15, 16, 18 |
| `lib/views/widgets/base64_image_viewer.dart` | 0 | 1 | 12 |
| `lib/views/widgets/notification_bell.dart` | 0 | 7 | 9, 10, 12, 13, 14, 15, 18 |

### Exact literal colors and size/radius values

- `lib/config/colors.dart` — hex: 0xFF0F172A, 0xFF16A34A, 0xFF1E293B, 0xFF1E3A6E, 0xFF1E56A0, 0xFF22C55E, 0xFF2563EB, 0xFF334155, 0xFF3B82F6, 0xFF475569, 0xFF64748B, 0xFF94A3B8, 0xFFCBD5E1, 0xFFE2E8F0, 0xFFEF4444, 0xFFF0F4F9, 0xFFF1F5F9, 0xFFF59E0B; circular radii: none; explicit dimensions/elevations: none.
- `lib/main.dart` — hex: none; circular radii: none; explicit dimensions/elevations: 16, 48.
- `lib/providers/data_provider.dart` — hex: 0xFF16A34A, 0xFF1E3A6E, 0xFFDC2626; circular radii: none; explicit dimensions/elevations: none.
- `lib/providers/theme_provider.dart` — hex: none; circular radii: 12, 16; explicit dimensions/elevations: 0, 2.
- `lib/views/screens/admin/admin_screen.dart` — hex: 0xFF16A34A, 0xFF22C55E, 0xFF64748B, 0xFF8B5CF6, 0xFF94A3B8, 0xFFDC2626, 0xFFEF4444; circular radii: 8, 9, 10, 12, 14, 16, 20, 24; explicit dimensions/elevations: 1, 1.4, 1.5, 2, 3, 4, 5, 6, 8, 10, 12, 13, 14, 16, 18, 20, 22, 24, 28, 32, 34, 40, 48, 50, 56, 120.
- `lib/views/screens/admin/subscriber_details_screen.dart` — hex: none; circular radii: 8, 10, 12, 16, 20; explicit dimensions/elevations: 0, 1.5, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 36, 220.
- `lib/views/screens/consumer/alerts_tab.dart` — hex: none; circular radii: 10, 14, 16; explicit dimensions/elevations: 2, 6, 7, 8, 12, 14, 20, 52.
- `lib/views/screens/consumer/bills_tab.dart` — hex: 0xFFB71C1C, 0xFFE53935; circular radii: 8, 10, 13, 14, 16, 24; explicit dimensions/elevations: 2, 3, 4, 6, 8, 10, 12, 14, 15, 16, 18, 20, 22, 24, 40, 52, 78, 160.
- `lib/views/screens/consumer/consumer_shell.dart` — hex: 0xFF64748B; circular radii: none; explicit dimensions/elevations: 0, 16.
- `lib/views/screens/consumer/home_tab.dart` — hex: 0xFF16A34A, 0xFF22C55E, 0xFF64748B, 0xFF8B5CF6, 0xFF94A3B8, 0xFFf59e0b; circular radii: 8, 10, 14, 16, 20; explicit dimensions/elevations: 1.2, 1.5, 2, 3, 5, 6, 8, 10, 11, 12, 14, 16, 18, 20, 32, 50.
- `lib/views/screens/consumer/profile_tab.dart` — hex: none; circular radii: 2, 8, 10, 12, 14, 16, 20, 24; explicit dimensions/elevations: 1, 1.4, 1.5, 2, 4, 6, 8, 10, 12, 15, 16, 18, 20, 22, 24, 40, 52, 80.
- `lib/views/screens/consumer/usage_tab.dart` — hex: none; circular radii: 6, 7, 8, 10, 14, 20; explicit dimensions/elevations: 1, 2, 4, 8, 10, 12, 16, 20, 22, 36, 48, 56, 68, 80, 190, 400.
- `lib/views/screens/login_screen.dart` — hex: none; circular radii: 10, 12, 16, 20, 28; explicit dimensions/elevations: 1.4, 1.5, 2, 4, 8, 12, 14, 16, 18, 20, 22, 28, 40.
- `lib/views/screens/register_screen.dart` — hex: none; circular radii: 9, 10, 12, 20, 28; explicit dimensions/elevations: 1.4, 1.5, 2, 4, 6, 8, 10, 12, 14, 16, 17, 18, 20, 22, 24, 28, 48.
- `lib/views/screens/setup_screen.dart` — hex: none; circular radii: 12, 16, 28; explicit dimensions/elevations: 2, 4, 8, 12, 14, 16, 20, 22, 24, 28, 44, 80.
- `lib/views/screens/super_admin/super_admin_screen.dart` — hex: 0xFF16213e, 0xFF1a1a2e; circular radii: 10, 12, 16, 20, 24; explicit dimensions/elevations: 1.5, 4, 8, 10, 12, 14, 16, 20, 22, 24, 48, 52.
- `lib/views/widgets/base64_image_viewer.dart` — hex: none; circular radii: 12; explicit dimensions/elevations: 8, 32, 120.
- `lib/views/widgets/notification_bell.dart` — hex: none; circular radii: 2, 10, 14, 24; explicit dimensions/elevations: 1, 1.1, 3, 4, 6, 7, 8, 12, 20, 24, 40, 56.

## Visual hierarchy and system problems

- Generator status is already first in home/overview, but competes with oversized gradient headers and saturated multicolour statistics. Preserve status text, schedule and controls; give status its own quiet, dominant panel.
- Admin has six horizontally scrollable text tabs. Discoverability is weak on narrow screens. Proposed presentation: labelled 3×2 navigation panel on phones and a navigation rail on wide layouts, bound to the existing controller and six destinations. No new destination or action.
- Cards use radii 8–24, shadows at many strengths, inconsistent outline rules, and decorative icon containers with different proportions. Use distinct status panels, flat ledger rows, grouped settings and restrained summary tiles.
- Blue/green/red/purple/orange compete; white text on bright success/warning fills and faded secondary text need contrast corrections. Dark mode has hardcoded light-border/light-muted values, white chart markers and bespoke super-admin colours.
- Typography falls back to platform fonts; Tajawal is named in login but not bundled or declared. Arabic and Latin metrics therefore vary by machine.
- Daily chart interpolates points with cubic curves and lacks accessible textual values/axes for most data. Replace only its visual rendering, retain source points and calculations.
- Repeated 600ms colour transitions, bounce/elastic scale and indefinite shimmer lack reduced-motion handling. Simplify appearance transitions, leave service/state timing intact.

## RTL and responsive risks

- Root forces RTL. Many physical left/right paddings, alignments, positioned badges and chevrons bypass directional APIs. Audit intent individually: Arabic back direction must remain correct; numerals/IDs/times/currency need isolated LTR spans without reversing their values.
- Chart canvas progresses left-to-right while weekday labels inherit RTL Row order: plotted values and labels can mismatch. Direction must be explicit and consistent, without changing data order/calculation.
- Home address Row uses a Text with ellipsis but no Flexible around that text; long addresses can overflow. Admin header name column is not Expanded. Tight subscriber rows combine avatar/details/chip/switch and can overflow at large text sizes.
- Multiple forms/sheets use fixed Column heights and viewInsets padding without consistent scrolling; keyboard plus large text can overflow. Receipt preview has fixed 160/220 heights; charts 190; usage empty state 400.
- Numeric strings combine Arabic, ₪, kWh and A in single Text nodes; device validation must cover mixed-direction dates, amounts and phone numbers.

## Accessibility risks and acceptance checks

- Text as small as 9sp (notification badge, monthly value), 10sp (chart axes/activity debug), 11sp (navigation, labels/status/metadata). Proposed minimum 12sp; body 16sp and explicit hierarchy.
- Forgot-password removes minimum target and uses shrinkWrap. Ampere GestureDetector is a tiny text row. Receipt-dialog close button removes padding/constraints. Several accept/reject buttons set Size.zero; filters and role controls use GestureDetector without button semantics. Enforce 48dp targets and focus/selected semantics later.
- Notification bell/theme/password visibility icons lack consistent tooltips/labels. Chart CustomPainter has no semantic description. Receipt Image.memory lacks a semantic label. Unread state relies partly on a tiny dot/colour; add accessible presentation descriptions, not new business state.
- Several status components already have text and icons: retain these. Do not replace status with colour alone. Validate light/dark text at >=4.5:1, interactive boundaries >=3:1; include selected, error, disabled and focus appearances.
- Actual TalkBack, RTL screenshots, 200% text scaling, contrast across composited fills and Android device checks are not yet run. Step 0 is source audit only.

## Scope conflicts to resolve within the visual-only boundary

- `providers/theme_provider.dart` mixes state/persistence with ThemeData. Later extract theme builders only, preserving notifier/provider logic byte-for-byte where possible; this file must be reported explicitly if touched.
- `providers/data_provider.dart` contains three literal activity colours. Providers are protected. Keep them unchanged and map the presentation to theme tokens in the UI; document that a literal-colour scan must exclude unchanged protected provider code. Do not silently refactor state to satisfy a styling scan.
- Existing counter widget test does not represent this router-based app. Record baseline failure/unrun status honestly rather than altering app behaviour to satisfy it.
- Source-only setup/alerts/security/help/add-subscriber helpers are included in the visual inventory but must not gain new routes/buttons. Existing broken jumps and mock error fallbacks are findings, not redesign fixes.

## Read coverage

All 29 files under `lib/` were inspected, including configuration, models, providers and services to identify protected boundaries. No live Firebase mutations were performed. Full file list:

- `lib/config/app_config.dart`
- `lib/config/colors.dart`
- `lib/config/router.dart`
- `lib/main.dart`
- `lib/models/alert_model.dart`
- `lib/models/bill_model.dart`
- `lib/models/complaint_model.dart`
- `lib/models/user_model.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/data_provider.dart`
- `lib/providers/theme_provider.dart`
- `lib/services/firebase_service.dart`
- `lib/services/image_service.dart`
- `lib/services/local_notification_service.dart`
- `lib/services/notification_service.dart`
- `lib/views/screens/admin/admin_screen.dart`
- `lib/views/screens/admin/subscriber_details_screen.dart`
- `lib/views/screens/consumer/alerts_tab.dart`
- `lib/views/screens/consumer/bills_tab.dart`
- `lib/views/screens/consumer/consumer_shell.dart`
- `lib/views/screens/consumer/home_tab.dart`
- `lib/views/screens/consumer/profile_tab.dart`
- `lib/views/screens/consumer/usage_tab.dart`
- `lib/views/screens/login_screen.dart`
- `lib/views/screens/register_screen.dart`
- `lib/views/screens/setup_screen.dart`
- `lib/views/screens/super_admin/super_admin_screen.dart`
- `lib/views/widgets/base64_image_viewer.dart`
- `lib/views/widgets/notification_bell.dart`
