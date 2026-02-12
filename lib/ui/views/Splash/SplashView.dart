import 'package:flutter/material.dart';
import '../../../core/utils/base_view.dart';
import 'SplashViewModel.dart';

class SplashView extends BaseView<SplashViewModel> {
  const SplashView({super.key});

  @override
  SplashViewModel createViewModel() => SplashViewModel();

  @override
  Widget buildView(BuildContext context, SplashViewModel viewModel) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Icon(
          Icons.search,
          size: 80,
          color: Colors.black,
        ),
      ),
    );
  }
}
