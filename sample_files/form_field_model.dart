import 'dart:collection';
import '../utils/app_logger.dart';

class FormFieldModel {
  final String key;
  final String type;
  final String? fetchUrl;
  final String? responseType;
  final String? restType;
  final List<String>? defaultValues;
  final dynamic defaultValue;
  final Map<String, dynamic> templateOptions;
  final String? hideExpression;
  final bool? hide;
  final List<FormFieldModel>? fieldGroup;
  final List<FormFieldModel>? fieldArray;
  final bool? autoClear;
  final Map<String, dynamic>? validators;
  final Map<String, dynamic>? attributes;

  FormFieldModel({
    required this.key,
    required this.type,
    this.fetchUrl,
    this.responseType,
    this.restType,
    this.defaultValues,
    this.defaultValue,
    required this.templateOptions,
    this.hideExpression,
    this.hide,
    this.fieldGroup,
    this.fieldArray,
    this.autoClear,
    this.validators,
    this.attributes,
  });

  // Factory constructor to build from JSON
  factory FormFieldModel.fromJson(Map<String, dynamic> json) {
    // Handle nested fieldGroup if present
    List<FormFieldModel>? nestedFields;
    if (json['fieldGroup'] != null) {
      nestedFields = List.from(json['fieldGroup'])
          .map((field) => FormFieldModel.fromJson(field))
          .toList();
    }

    // Handle fieldArray for array type fields
    List<FormFieldModel>? arrayFields;
    if (json['fieldArray'] != null) {
      // Handle both formats: direct array or object with fieldGroup
      if (json['fieldArray'] is List) {
        arrayFields = List.from(json['fieldArray'])
            .map((field) => FormFieldModel.fromJson(field))
            .toList();
      } else if (json['fieldArray']['fieldGroup'] != null) {
        arrayFields = List.from(json['fieldArray']['fieldGroup'])
            .map((field) => FormFieldModel.fromJson(field))
            .toList();
      }
    }

    return FormFieldModel(
      key: json['key'] ?? '',
      type: json['type'] ?? 'input',
      fetchUrl: json['fetchUrl'],
      responseType: json['responseType'],
      restType: json['restType'],
      defaultValues: json['defaultValues']?.cast<String>(),
      defaultValue: json['defaultValue'],
      templateOptions: _parseTemplateOptionsWithOrder(json['templateOptions']),
      hideExpression: json['hideExpression'],
      hide: _parseBool(json['hide']),
      fieldGroup: nestedFields,
      fieldArray: arrayFields,
      autoClear: _parseBool(json['autoClear']),
      validators: json['validators']?.cast<String, dynamic>(),
      attributes: json['attributes']?.cast<String, dynamic>(),
    );
  }

  /// Check if this field should be hidden based on current form data
  bool shouldHide(Map<String, dynamic> formData) {
    // If explicitly hidden
    if (hide == true) return true;

    // Check hide expression
    if (hideExpression != null && hideExpression!.isNotEmpty) {
      return _evaluateHideExpression(hideExpression!, formData);
    }

    return false;
  }

  /// Evaluate hide expressions dynamically
  bool _evaluateHideExpression(String expression, Map<String, dynamic> formData) {
    try {
      String evaluatedExpression = expression;

      // Replace model.fieldName with actual values
      RegExp regex = RegExp(r'model\.(\w+)');
      evaluatedExpression = evaluatedExpression.replaceAllMapped(regex, (match) {
        String fieldName = match.group(1)!;
        dynamic value = formData[fieldName];

        if (value == null) {
          return 'null';
        } else if (value is String) {
          return "'$value'";
        } else if (value is bool) {
          return value.toString();
        } else if (value is num) {
          return value.toString();
        } else {
          return "'$value'";
        }
      });

      // Handle != operator
      if (evaluatedExpression.contains('!=')) {
        List<String> parts = evaluatedExpression.split('!=').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left != right;
        }
      }

      // Handle == or === operator
      if (evaluatedExpression.contains('==')) {
        evaluatedExpression = evaluatedExpression.replaceAll('===', '==');
        List<String> parts = evaluatedExpression.split('==').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left == right;
        }
      }

      // Handle negation expressions like !model.fieldName
      if (evaluatedExpression.startsWith('!')) {
        String value = evaluatedExpression.substring(1).trim();
        // Falsy: null, empty, empty string, false
        return value == 'null' || value.isEmpty || value == "''" || value == 'false';
      }

      // Default to false for unhandled expressions
      return false;
    } catch (e) {
      AppLogger.error('evaluating hideExpression: $expression, Error: $e');
      return false;
    }
  }

  /// Helper method to safely parse boolean values from JSON
  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// Parse templateOptions and store the original key order
  /// This ensures display fields are rendered in the order specified in the journey JSON
  static Map<String, dynamic> _parseTemplateOptionsWithOrder(dynamic templateOptionsJson) {
    if (templateOptionsJson == null) {
      return LinkedHashMap<String, dynamic>();
    }

    final Map<String, dynamic> options = LinkedHashMap<String, dynamic>.from(templateOptionsJson as Map);

    // Store the original key order (excluding internal keys)
    final List<String> keyOrder = options.keys
        .where((key) => key != 'fetchUrl' && key != '_keyOrder')
        .toList();

    // Store the key order in the map itself for later retrieval
    options['_keyOrder'] = keyOrder;

    return options;
  }

  /// Check if this field is required (handles conditional expressions)
  bool isRequired(Map<String, dynamic> formData) {
    final required = templateOptions['required'];
    if (required == null) return false;

    // Handle boolean values
    if (required is bool) return required;

    // Handle string values
    if (required is String) {
      // Simple true/false strings
      if (required.toLowerCase() == 'true') return true;
      if (required.toLowerCase() == 'false') return false;

      // For conditional expressions, evaluate them
      if (required.contains('model.')) {
        return _evaluateRequiredExpression(required, formData);
      }
    }

    return false;
  }

  /// Alias method for isRequired to match the calls in dynamic_form.dart
  bool isRequiredForFormData(Map<String, dynamic> formData) {
    return isRequired(formData);
  }

  /// Evaluate conditional required expressions
  bool _evaluateRequiredExpression(String expression, Map<String, dynamic> formData) {
    try {
      String evaluatedExpression = expression;

      // Replace model.fieldName with actual values
      RegExp regex = RegExp(r'model\.(\w+)');
      evaluatedExpression = evaluatedExpression.replaceAllMapped(regex, (match) {
        String fieldName = match.group(1)!;
        dynamic value = formData[fieldName];

        if (value == null) {
          return 'null';
        } else if (value is String) {
          return "'$value'";
        } else if (value is bool) {
          return value.toString();
        } else if (value is num) {
          return value.toString();
        } else {
          return "'$value'";
        }
      });

      // Handle basic expressions
      if (evaluatedExpression.contains('!=')) {
        List<String> parts = evaluatedExpression.split('!=').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left != right;
        }
      }

      if (evaluatedExpression.contains('==')) {
        evaluatedExpression = evaluatedExpression.replaceAll('===', '==');
        List<String> parts = evaluatedExpression.split('==').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left == right;
        }
      }

      // Default to false for unhandled expressions
      return false;
    } catch (e) {
      AppLogger.error('evaluating required expression: $expression, Error: $e');
      return false;
    }
  }

  /// Helper to get button configuration from templateOptions (for stepper steps)
  Map<String, dynamic> get buttonConfig {
    return {
      'navigationMode': templateOptions['navigationMode'] ?? 'submit',
      'nextButtonLabel': templateOptions['nextButtonLabel'] ?? 'Next',
      'nextButtonAction': templateOptions['nextButtonAction'] ?? 'navigate',
      'submitButtonLabel': templateOptions['submitButtonLabel'] ?? 'Submit',
      'submitButtonAction': templateOptions['submitButtonAction'] ?? 'submit',
      'backButtonLabel': templateOptions['backButtonLabel'] ?? 'Back',
      'showBackButton': templateOptions['showBackButton'] ?? false,
    };
  }

  /// Helper to check if this field is a step
  bool get isStep => type.toLowerCase() == 'step';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'fetchUrl': fetchUrl,
      'responseType': responseType,
      'restType': restType,
      'defaultValues': defaultValues,
      'defaultValue': defaultValue,
      'templateOptions': templateOptions,
      'hideExpression': hideExpression,
      'hide': hide,
      'fieldGroup': fieldGroup?.map((f) => f.toJson()).toList(),
      'fieldArray': fieldArray?.map((f) => f.toJson()).toList(),
      'autoClear': autoClear,
      'validators': validators,
      'attributes': attributes,
    };
  }
} 