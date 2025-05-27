import 'package:flutter/material.dart';
import '../../config/constants.dart';

class SplashView extends StatefulWidget {
  final AnimationController animationController;

  const SplashView({Key? key, required this.animationController})
    : super(key: key);

  @override
  _SplashViewState createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  Widget build(BuildContext context) {
    final _introductionanimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0.0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Interval(0.0, 0.2, curve: Curves.fastOutSlowIn),
      ),
    );
    return SlideTransition(
      position: _introductionanimation,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image
                Image.asset(
                  'assets/introduction_animation/screen1.png',
                  fit: BoxFit.cover,
                ),
                // Title
                Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: SizedBox(
                    height: 50,
                    child: Image.asset(
                      'assets/logo/logo-header.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Description
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    "Your space to manage shared expenses with your crew. Create groups, log expenses, and keep everything on track.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 32),
                // Button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: InkWell(
                    onTap: () {
                      widget.animationController.animateTo(
                        0.2,
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      height: 58,
                      padding: EdgeInsets.only(
                        left: 56.0,
                        right: 56.0,
                        top: 16,
                        bottom: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: kPrimaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withAlpha((0.5 * 255).round()),
                            offset: Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        "Let’s go",
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ), // closes SingleChildScrollView
        ), // closes ConstrainedBox
      ), // closes Center
    ); // closes SlideTransition
  }
}
