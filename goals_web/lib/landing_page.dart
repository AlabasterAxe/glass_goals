import 'package:flutter/material.dart';

import 'app_bar.dart';
import 'styles.dart';
import 'widgets/gg_button.dart';

const String TEXT_COLUMN_1 =
    '''Glass Goals is a cross between a to-do list and a journal. The purpose is to maximize the likelihood of achieving your goals and aggregate information about your experiences so that you can continually improve along the dimensions that are important to you. 
                          
You might be thinking to yourself, there are a billion project management, task tracker and to-do list apps out there. Why not just use one of those?

The real answer is that Glass Goals started life as an app for Google Glass. The original idea was that I would constantly have a heads up reminder of my active goal.''';

const String TEXT_COLUMN_2 =
    '''I went on to build a web app companion to the Glass app and got carried away.
¯\\_(ツ)_/¯

Along the way I realized there were many ways in which the project management systems that I had used in the past didn't align well with the way my brain works. After working through these problems for a year or so, I've gotten to a point where the system has some interesting properties that I haven't seen elsewhere. I'm sharing it now in case it's useful to others.''';

const String TEXT_EXPRESS_INTENTIONS =
    '''The first and most difficult part of Glass Goals is deciding what you want to achieve. In my experience, most people don’t spend a lot of time really considering what they want out of life. Glass Goals invites you to think about what you want on the broadest possible scales.

Then, you put those desires into the app.''';

const String TEXT_RECOMMIT_TO_GOALS =
    '''In Glass Goals, you start every day with a blank slate. The app will reflect what you’ve said you want to accomplish but, ultimately, you need to deliberately decide what you are going to work on each day. 

Some productivity systems automatically assign things for you to do, or designate time on your calendar to do things. In my experience, without the intentional step of adding an item to your daily list, it’s too easy to just ignore all of the automatic reminders.''';

const String TEXT_DO_THE_THING =
    '''Ultimately, you actually have to do real work. One of the goals of Glass Goals is to spend less time fiddling with your task management system and more time doing the things that you are passionate about. Write that novel, build a house, fly to the moon, etc.''';

const String TEXT_REFLECT =
    '''The last and most important part of Glass Goals is the opportunity to consider how things went. You look back at the day, month, year and you can look at the stuff you’ve done and what you’ve learned from everything.

This is intended to be a recursive process. The ideal here is that when you’re considering how your week went, you can use your daily reflections and when you’re considering how your month went, you have your weekly reflections, so on and so forth.

With this process, you are continually reflecting on how things are going giving yourself space to learn from your work and reconsider your goals, your approach, your techniques, etc.''';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  _paragraph(String text) {
    return Padding(
      padding: EdgeInsets.all(uiUnit(4)),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: mainTextStyle,
      ),
    );
  }

  _section({
    required int sectionNumber,
    required String title,
    required String body,
    required bool isNarrow,
  }) {
    final (textColor, backgroundColor) = switch (sectionNumber) {
      1 => (darkPurpleColor, palePurpleColor),
      2 => (darkBrownColor, yellowColor),
      3 => (darkGreenColor, paleGreenColor),
      4 => (darkBlueColor, paleBlueColor),
      _ => (darkBlueColor, paleBlueColor),
    };

    return Padding(
        padding: EdgeInsets.all(uiUnit(4)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
          ),
          child: Column(
            children: [
              SizedBox(
                height: uiUnit(4),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$sectionNumber.",
                      style: enormousTitleTextStyle.copyWith(
                        fontSize: uiUnit(isNarrow ? 15 : 20),
                        color: textColor.withOpacity(.2),
                        height: 0.725,
                      )),
                  Container(
                    color: backgroundColor,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: uiUnit(1), horizontal: uiUnit(4)),
                      child: Text(
                        title,
                        style: mainTextStyle.copyWith(
                          color: textColor,
                          fontSize: uiUnit(isNarrow ? 7.5 : 10),
                        ),
                      ),
                    ),
                  ),
                  Container(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0)
                    .copyWith(bottom: uiUnit(4)),
                child: Container(
                  height: uiUnit(1.5),
                  color: darkBlueColor,
                ),
              ),
              Text(
                body,
                style: mainTextStyle,
              ),
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: GlassGoalsAppBar(
        isNarrow: isNarrow,
        signedIn: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'ACCOMPLISH YOUR GOALS.',
              style: isNarrow
                  ? enormousTitleTextStyle.copyWith(
                      fontSize: uiUnit(10),
                    )
                  : enormousTitleTextStyle,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                height: uiUnit(2),
                color: darkBlueColor,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 900,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: IntrinsicHeight(
                  child: isNarrow
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  width: uiUnit(1),
                                  color: darkBlueColor,
                                ),
                              ),
                              Expanded(
                                child: _paragraph(
                                  "$TEXT_COLUMN_1\n$TEXT_COLUMN_2",
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  width: uiUnit(1),
                                  color: darkBlueColor,
                                ),
                              ),
                            ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  width: uiUnit(1),
                                  color: darkBlueColor,
                                ),
                              ),
                              Expanded(
                                child: _paragraph(
                                  TEXT_COLUMN_1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  width: uiUnit(0.5),
                                  color: darkBlueColor,
                                ),
                              ),
                              Expanded(
                                  child: _paragraph(
                                TEXT_COLUMN_2,
                              )),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  width: uiUnit(1),
                                  color: darkBlueColor,
                                ),
                              ),
                            ]),
                ),
              ),
            ),
            _section(
              sectionNumber: 1,
              title: 'Express your intentions.',
              body: TEXT_EXPRESS_INTENTIONS,
              isNarrow: isNarrow,
            ),
            _section(
              sectionNumber: 2,
              title: 'Recommit to your goals.',
              body: TEXT_RECOMMIT_TO_GOALS,
              isNarrow: isNarrow,
            ),
            _section(
              sectionNumber: 3,
              title: 'Do the thing.',
              body: TEXT_DO_THE_THING,
              isNarrow: isNarrow,
            ),
            _section(
              sectionNumber: 4,
              title: 'Reflect on your efforts.',
              body: TEXT_REFLECT,
              isNarrow: isNarrow,
            ),
            Container(
                height: uiUnit(50),
                child: Center(
                    child: GlassGoalsButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/register');
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: uiUnit(1), vertical: uiUnit(4)),
                    child: Text('GET STARTED',
                        style: mainTextStyle.copyWith(
                          color: lightBackground,
                          fontSize: uiUnit(6.5),
                        )),
                  ),
                )))
          ],
        ),
      ),
    );
  }
}
