import 'form_field_model.dart';

class FormJourneyModel {
  final String type;
  final List<FormFieldModel> fieldGroup;
  final int? currentStep;
  final String? appBarLabel;

  FormJourneyModel({
    required this.type,
    required this.fieldGroup,
    this.currentStep,
    this.appBarLabel,
  });

  factory FormJourneyModel.fromJson(Map<String, dynamic> json) {
    return FormJourneyModel(
      type: json['type'] ?? 'form',
      currentStep: json['currentStep'],
      appBarLabel: json['appBarLabel'],
      fieldGroup: List.from(json['fieldGroup'] ?? [])
          .map((field) => FormFieldModel.fromJson(field))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'currentStep': currentStep,
      'appBarLabel': appBarLabel,
      'fieldGroup': fieldGroup.map((f) => f.toJson()).toList(),
    };
  }

  /// Helper to check if journey is multi-step (stepper type)
  bool get isStepper => type.toLowerCase() == 'stepper';

  /// Helper to check if journey is tabbed type
  bool get isTabbed => type.toLowerCase() == 'tabbed';

  /// Get all steps (fields with type: 'step' or fields with nested fieldGroup) in this journey
  List<FormFieldModel> get steps {
    if (!isStepper) return [];
    // A step is either explicitly typed as 'step' OR has a nested fieldGroup
    return fieldGroup.where((field) =>
      field.type.toLowerCase() == 'step' ||
      (field.fieldGroup != null && field.fieldGroup!.isNotEmpty)
    ).toList();
  }

  /// Get all tabs (fields with type: 'tab') in this journey
  List<FormFieldModel> get tabs {
    if (!isTabbed) return [];
    return fieldGroup.where((field) =>
      field.type.toLowerCase() == 'tab'
    ).toList();
  }
} 