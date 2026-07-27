import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/helpers/plan_type_ui_helper.dart';

void main() {
  group('PlanTypeUiHelper', () {
    test('selectableTypes has SIMPLE and MULTI_DAY, in that order', () {
      expect(PlanTypeUiHelper.selectableTypes, hasLength(2));
      expect(PlanTypeUiHelper.selectableTypes[0].value, 'SIMPLE');
      expect(PlanTypeUiHelper.selectableTypes[0].label, 'Simple');
      expect(PlanTypeUiHelper.selectableTypes[0].icon, Icons.wb_sunny_outlined);
      expect(PlanTypeUiHelper.selectableTypes[1].value, 'MULTI_DAY');
      expect(PlanTypeUiHelper.selectableTypes[1].label, 'Multi-Day');
      expect(PlanTypeUiHelper.selectableTypes[1].icon, Icons.luggage_outlined);
    });

    test('getIcon returns the compact-badge icon per plan type', () {
      expect(PlanTypeUiHelper.getIcon('SIMPLE'), Icons.place);
      expect(PlanTypeUiHelper.getIcon('MULTI_DAY'), Icons.date_range);
      expect(PlanTypeUiHelper.getIcon('ROAD_TRIP'), Icons.directions_car);
      expect(PlanTypeUiHelper.getIcon('UNKNOWN'), Icons.map);
    });

    test('formatLabel title-cases each underscore-separated word', () {
      expect(PlanTypeUiHelper.formatLabel('MULTI_DAY'), 'Multi Day');
      expect(PlanTypeUiHelper.formatLabel('SIMPLE'), 'Simple');
    });
  });
}
