import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';

/// Read insets from the modal route, never from the page which opened it.
Future<T?> showPortalFormSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  ShapeBorder? shape,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      shape: shape,
      builder: (context) => PortalFocusReveal(
        child: LayoutBuilder(builder: (context, constraints) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final height = math.max(0.0, constraints.maxHeight - keyboard);
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.95),
              child: SingleChildScrollView(
                child: Builder(builder: builder),
              ),
            ),
          );
        }),
      ),
    );

/// AlertDialog already applies viewInsets and constrains/scrolls its content.
/// Add focus revelation without applying the keyboard inset a second time.
Future<T?> showPortalFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showDialog<T>(
      context: context,
      builder: (context) => PortalFocusReveal(child: Builder(builder: builder)),
    );

class PortalFocusReveal extends StatefulWidget {
  final Widget child;
  const PortalFocusReveal({super.key, required this.child});

  @override
  State<PortalFocusReveal> createState() => _PortalFocusRevealState();
}

class _PortalFocusRevealState extends State<PortalFocusReveal>
    with WidgetsBindingObserver {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_reveal);
  }

  @override
  void didChangeMetrics() => _reveal();

  void _reveal() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final field = FocusManager.instance.primaryFocus?.context;
      if (field == null ||
          field.findAncestorStateOfType<_PortalFocusRevealState>() != this) {
        return;
      }
      BuildContext target = field;
      field.visitAncestorElements((element) {
        if (element.widget is TextField) {
          target = element;
          return false;
        }
        return true;
      });
      Scrollable.ensureVisible(
        target,
        duration: PortalTokens.motion,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_reveal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Never pop a replacement page when a save finishes after dismissal/redirect.
bool completePortalSave<T>(BuildContext context,{T? result,String? message}) {
 if(!context.mounted)return false;
 final route=ModalRoute.of(context);
 if(route is! PopupRoute || !route.isCurrent)return false;
 final messenger=ScaffoldMessenger.maybeOf(context);
 Navigator.of(context).pop(result);
 if(message!=null)messenger?.showSnackBar(SnackBar(content:Text(message)));
 return true;
}

bool returnAfterPortalSave(BuildContext context,String message){
 if(!context.mounted || ModalRoute.of(context)?.isCurrent!=true || !Navigator.of(context).canPop())return false;
 final messenger=ScaffoldMessenger.maybeOf(context);
 Navigator.of(context).pop();
 messenger?.showSnackBar(SnackBar(content:Text(message)));
 return true;
}
