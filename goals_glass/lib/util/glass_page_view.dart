import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Container,
        PageController,
        PageView,
        State,
        StatefulWidget,
        Widget;

import 'app_context.dart' show AppContext;

class GlassPageView extends StatefulWidget {
  final List<Widget> children;
  const GlassPageView({super.key, required this.children});

  @override
  State<GlassPageView> createState() => _GlassPageViewState();
}

class _GlassPageViewState extends State<GlassPageView> {
  final _pageController = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageController.addListener(() {
      AppContext.of(context).interactionSubject.add(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: widget.children,
    );
  }
}
