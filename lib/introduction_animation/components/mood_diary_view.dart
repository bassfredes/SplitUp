import 'package:flutter/material.dart';

class MoodDiaryView extends StatelessWidget {
  final AnimationController animationController;

  const MoodDiaryView({Key? key, required this.animationController})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _firstHalfAnimation = Tween<Offset>(
      begin: Offset(1, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
      ),
    );
    final _secondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-1, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );

    final _moodFirstHalfAnimation = Tween<Offset>(
      begin: Offset(2, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
      ),
    );
    final _moodSecondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-2, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );
    final _imageFirstHalfAnimation = Tween<Offset>(
      begin: Offset(4, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
      ),
    );
    final _imageSecondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-4, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );

    return SlideTransition(
      position: _firstHalfAnimation,
      child: SlideTransition(
        position: _secondHalfAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Mood Diary",
                    style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold),
                  ),
                  SlideTransition(
                    position: _moodFirstHalfAnimation,
                    child: SlideTransition(
                      position: _moodSecondHalfAnimation,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 64,
                          right: 64,
                          top: 16,
                          bottom: 16,
                        ),
                        child: Text(
                          "Stay updated, wherever you are. Get alerts on new expenses, payments, and group updates.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _imageFirstHalfAnimation,
                    child: SlideTransition(
                      position: _imageSecondHalfAnimation,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 350, maxHeight: 250),
                        child: Image.asset(
                          'assets/introduction_animation/screen4.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
