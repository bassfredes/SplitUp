import 'package:flutter/material.dart';

class WelcomeView extends StatelessWidget {
  final AnimationController animationController;
  const WelcomeView({Key? key, required this.animationController})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _firstHalfAnimation = Tween<Offset>(
      begin: Offset(1, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );
    final _secondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-1, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.8, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );

    final _welcomeFirstHalfAnimation = Tween<Offset>(
      begin: Offset(2, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );

    final _welcomeImageAnimation = Tween<Offset>(
      begin: Offset(4, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );

    final screenSize = MediaQuery.of(context).size;
    // Usar tamaños fijos para desktop y proporcionales para mobile
    double maxWidth = 450;
    double titleFontSize = 32;
    double descFontSize = 18;
    double horizontalPadding = 24;
    if (screenSize.width < 600) {
      // Mobile
      titleFontSize = 24;
      descFontSize = 15;
      horizontalPadding = 16;
    }

    return SlideTransition(
      position: _firstHalfAnimation,
      child: SlideTransition(
        position: _secondHalfAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SlideTransition(
                    position: _welcomeImageAnimation,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth * 0.8,
                        maxHeight: screenSize.height * 0.4,
                      ),
                      child: Image.asset(
                        'assets/introduction_animation/screen5.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _welcomeFirstHalfAnimation,
                    child: Text(
                      "Welcome to SplitUp",
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    child: Text(
                      "Ready to simplify your group expenses? Let's get started!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: descFontSize),
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
