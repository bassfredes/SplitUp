import 'package:flutter/material.dart';

class ManageSmarter extends StatelessWidget {
  final AnimationController animationController;

  const ManageSmarter({Key? key, required this.animationController})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _firstHalfAnimation = Tween<Offset>(
      begin: Offset(1, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
      ),
    );
    final _secondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-1, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
      ),
    );
    final _relaxFirstHalfAnimation = Tween<Offset>(
      begin: Offset(2, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
      ),
    );
    final _relaxSecondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-2, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
      ),
    );

    final _imageFirstHalfAnimation = Tween<Offset>(
      begin: Offset(4, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
      ),
    );
    final _imageSecondHalfAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-4, 0),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
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
                  SlideTransition(
                    position: _imageFirstHalfAnimation,
                    child: SlideTransition(
                      position: _imageSecondHalfAnimation,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 350, maxHeight: 250),
                        child: Image.asset(
                          'assets/introduction_animation/screen3.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _relaxFirstHalfAnimation,
                    child: SlideTransition(
                      position: _relaxSecondHalfAnimation,
                      child: Text(
                        "Manage Smarter",
                        style: TextStyle(
                          fontSize: 26.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 64,
                      right: 64,
                      bottom: 16,
                      top: 16,
                    ),
                    child: Text(
                      "Smart tools for shared decisions. Split your way: equal, custom, or fixed. Upload receipts too.",
                      textAlign: TextAlign.center,
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
