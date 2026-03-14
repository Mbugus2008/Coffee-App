import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoffeeBeanLogo extends StatelessWidget {
  const CoffeeBeanLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo/coffee_bean.svg',
      width: size,
      height: size,
    );
  }
}

class BrandedAppBarTitle extends StatelessWidget {
  const BrandedAppBarTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoffeeBeanLogo(size: 22),
        const SizedBox(width: 8),
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
