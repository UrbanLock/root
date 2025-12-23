import 'package:flutter/cupertino.dart';

enum LockerType {
  sportivi('Sportivi', CupertinoIcons.sportscourt_fill),
  personali('Personali', CupertinoIcons.bag_fill),
  petFriendly('Pet-Friendly', CupertinoIcons.heart_fill),
  commerciali('Commerciali', CupertinoIcons.cart_fill),
  cicloturistici('Cicloturistici', CupertinoIcons.location_fill);

  final String label;
  final IconData icon;

  const LockerType(this.label, this.icon);
}





