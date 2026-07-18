import 'package:flutter/material.dart';

import 'app.dart';
import 'data/household_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HouseholdApp(repository: HouseholdRepository()));
}
