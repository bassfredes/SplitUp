import 'package:splitup_application/services/settings_service.dart';
import 'components/relax_view.dart';
import 'components/center_next_button.dart';
import 'components/splash_view.dart';
import 'components/top_back_skip_view.dart';
import 'components/welcome_view.dart';
import 'components/manage_smarter.dart';
import 'components/mood_diary_view.dart';
import 'package:flutter/material.dart';

class IntroductionAnimationScreen extends StatefulWidget {
  const IntroductionAnimationScreen({Key? key}) : super(key: key);

  @override
  _IntroductionAnimationScreenState createState() =>
      _IntroductionAnimationScreenState();
}

class _IntroductionAnimationScreenState
    extends State<IntroductionAnimationScreen> with TickerProviderStateMixin {
  AnimationController? _animationController;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 8));
    _animationController?.animateTo(0.0);
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool _dragHandled = false;
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 225, 247, 244),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final value = _animationController?.value ?? 0.0;
          if (_dragHandled) return;
          // Drag izquierda (avanzar)
          if (details.delta.dx < -10) {
            if (value > 0.0 && value < 0.8) {
              _dragHandled = true;
              _onNextClick();
            }
          }
          // Drag derecha (retroceder)
          else if (details.delta.dx > 10) {
            if (value > 0.0) {
              _dragHandled = true;
              _onBackClick();
            }
          }
        },
        onHorizontalDragEnd: (_) {
          _dragHandled = false;
        },
        child: ClipRect(
          child: Stack(
            children: [
              SplashView(
                animationController: _animationController!,
              ),
              RelaxView(
                animationController: _animationController!,
              ),
              ManageSmarter(
                animationController: _animationController!,
              ),
              MoodDiaryView(
                animationController: _animationController!,
              ),
              WelcomeView(
                animationController: _animationController!,
              ),
              TopBackSkipView(
                onBackClick: _onBackClick,
                onSkipClick: _onSkipClick,
                animationController: _animationController!,
              ),
              CenterNextButton(
                animationController: _animationController!,
                onNextClick: _onNextClick,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSkipClick() {
    _animationController?.animateTo(0.8,
        duration: Duration(milliseconds: 1200));
  }

  void _onBackClick() {
    if (_animationController!.value >= 0 &&
        _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.0);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.2);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.8 &&
        _animationController!.value <= 1.0) {
      _animationController?.animateTo(0.8);
    }
  }

  void _onNextClick() {
    if (_animationController!.value >= 0 &&
        _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.8);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _endIntroduction();
    } else {
      _endIntroduction();
    }
  }

  Future<void> _endIntroduction() async {
    await SettingsService.instance.setHasSeenIntro(true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
