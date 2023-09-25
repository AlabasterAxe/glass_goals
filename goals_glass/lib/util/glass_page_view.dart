import 'package:flutter/widgets.dart'
    show BuildContext, PageController, PageView, State, StatefulWidget, Widget;

import 'app_context.dart' show AppContext;

class GlassPageView extends StatefulWidget {
  final List<Widget> children;
  final PageController? controller;
  const GlassPageView({super.key, required this.children, this.controller});

  @override
  State<GlassPageView> createState() => _GlassPageViewState();
}

class _GlassPageViewState extends State<GlassPageView> {
  late final _pageController = widget.controller ?? PageController();

  pageListener() {
    AppContext.of(context).interactionSubject.add(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageController.addListener(pageListener);
  }

  @override
  void dispose() {
    super.dispose();

    if (widget.controller != null) {
      widget.controller!.removeListener(pageListener);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: widget.children,
    );
  }
}
