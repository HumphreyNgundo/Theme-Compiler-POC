import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../configuration/client_config.dart';
import '../models/form_field_model.dart';
import '../utils/app_logger.dart';
import '../utils/color_palette.dart';
import '../utils/contact_picker.dart';
import '../utils/phone_number_validator.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/contact_picker_util.dart';
import '../widgets/loan_amount_field.dart';
import '../widgets/guarantor_field.dart';
import '../services/eligibility_service.dart';
import '../services/digital_loans_service.dart';
import 'dart:io';

class DynamicForm extends StatefulWidget {
  final List<FormFieldModel> fields;
  final void Function(String, dynamic) onChanged;
  final Map<String, dynamic> formData;
  final void Function(bool)? onEmailValidationErrorChanged;
  final void Function(bool)? onValidationChanged;
  final Map<String, FocusNode>? focusNodes;
  final Map<String, String?>? validationMessages;
  final Map<String, bool>? validationLoadingStates;
  final bool isDarkMode;
  final String? eloanCode;
  final String? serviceCode;
  final void Function(String key, String phoneNumber)? onContactPicked;
  final Set<String>? lockedFieldKeys;
  final VoidCallback? onLockedFieldTapped;

  const DynamicForm({
    Key? key,
    required this.fields,
    required this.onChanged,
    required this.formData,
    this.onEmailValidationErrorChanged,
    this.onValidationChanged,
    this.focusNodes,
    this.validationMessages,
    this.validationLoadingStates,
    this.isDarkMode = false,
    this.eloanCode,
    this.serviceCode,
    this.onContactPicked,
    this.lockedFieldKeys,
    this.onLockedFieldTapped,
  }) : super(key: key);

  @override
  _DynamicFormState createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  late Map<String, dynamic> localFormData;
  Map<String, String?> fieldErrors = {};
  Map<String, TextEditingController> controllers = {};
  Map<String, List<String>> fieldDependencies = {};
  Map<String, bool> fieldVisibility = {};
  Map<String, double> eligibleAmounts = {};
  Map<String, bool> eligibilityCheckLoading = {};
  Map<String, String> eligibilityMessages = {};
  Map<String, bool> _focusNodeListenerSetup = {};
  final EligibilityService _eligibilityService = EligibilityService();
  int _guarantorCountNeeded = 0;
  bool _isValidatingGuarantor = false;
  String _validatingGuarantorPhone = '';
  int _guarantorPending = 0;

  ClientColorPalette get colors => ClientThemeManager().colors;

  /// Convert a plural label to singular form
  String _singularize(String label) {
    final trimmed = label.replaceAll('Business ', '').trim();
    if (trimmed.endsWith('ies')) {
      return '${trimmed.substring(0, trimmed.length - 3)}y';
    } else if (trimmed.endsWith('s')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    localFormData = Map<String, dynamic>.from(widget.formData);
    _initializeControllers(widget.fields);
    _buildDependencyMap(widget.fields);
    _updateFieldVisibility();
  }

  @override
  void didUpdateWidget(DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update localFormData when parent formData changes (e.g., auto-selection)
    bool hasChanges = false;
    widget.formData.forEach((key, value) {
      if (localFormData[key] != value) {
        hasChanges = true;
      }
    });

    if (hasChanges) {
      setState(() {
        widget.formData.forEach((key, value) {
          if (localFormData[key] != value) {
            localFormData[key] = value;

            // Update controller if it exists
            if (controllers.containsKey(key)) {
              controllers[key]!.text = value?.toString() ?? '';
            }
          }
        });
      });
    }
  }

  void _initializeControllers(List<FormFieldModel> fields) {
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _initializeControllers(field.fieldGroup!);
        continue;
      }

      if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        _initializeControllers(field.fieldArray!);
        continue;
      }

      if (['input', 'currency', 'password']
              .contains(field.type.toLowerCase()) ||
          ['text', 'number', 'currency', 'password']
              .contains(field.templateOptions['type'])) {
        controllers[field.key] = TextEditingController(
            text: widget.formData[field.key]?.toString() ?? '');
      }
    }
  }

  void _buildDependencyMap(List<FormFieldModel> fields) {
    fieldDependencies.clear();
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _buildDependencyMap(field.fieldGroup!);
        continue;
      }

      if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        _buildDependencyMap(field.fieldArray!);
      }

      if (field.hideExpression != null) {
        List<String> dependencies =
            _extractDependenciesFromExpression(field.hideExpression!);
        if (dependencies.isNotEmpty) {
          fieldDependencies[field.key] = dependencies;
        }
      }
    }
  }

  List<String> _extractDependenciesFromExpression(String expression) {
    List<String> dependencies = [];
    RegExp regex = RegExp(r'model\.(\w+)');
    Iterable<RegExpMatch> matches = regex.allMatches(expression);

    for (RegExpMatch match in matches) {
      String fieldName = match.group(1)!;
      if (!dependencies.contains(fieldName)) {
        dependencies.add(fieldName);
      }
    }
    return dependencies;
  }

  void _updateFieldVisibility() {
    Map<String, bool> previousVisibility = Map.from(fieldVisibility);
    List<FormFieldModel> allFields = _getAllFieldsFlat(widget.fields);

    for (var field in allFields) {
      bool shouldHide = field.shouldHide(localFormData);
      fieldVisibility[field.key] = !shouldHide;

      final wasVisible = previousVisibility[field.key] ?? true;
      final isNowVisible = !shouldHide;
      fieldVisibility[field.key] = isNowVisible;

      if (wasVisible && !isNowVisible) {
        final bool autoClear = field.autoClear == true ||
            field.templateOptions['autoClear'] == true;
        if (autoClear) {
          // Clear local value
          if (localFormData.containsKey(field.key)) {
            localFormData.remove(field.key);
          }
          // Clear text controller if present
          controllers[field.key]?.clear();
        }
      }

      if (previousVisibility[field.key] != fieldVisibility[field.key]) {
        AppLogger.info("Visibility changed for ${field.key}: ${!shouldHide}");
      }
    }
  }

  List<FormFieldModel> _getAllFieldsFlat(List<FormFieldModel> fields) {
    List<FormFieldModel> flatFields = [];
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        flatFields.addAll(_getAllFieldsFlat(field.fieldGroup!));
      } else if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        flatFields.addAll(_getAllFieldsFlat(field.fieldArray!));
      } else {
        flatFields.add(field);
      }
    }
    return flatFields;
  }

  void _handleFieldChange(FormFieldModel field, dynamic value) {
    setState(() {
      localFormData[field.key] = value;

      // Real-time validation for email fields
      if (_isEmailField(field)) {
        _validateEmailField(field, value?.toString() ?? '');
      } else {
        // Perform custom validation
        _performCustomValidation(field, value);

        // Perform date range validation for date fields
        if (field.type == 'input' && field.templateOptions['type'] == 'date') {
          _performDateRangeValidation(field, value);
        }

        // Basic required field validation
        if (field.isRequiredForFormData(localFormData)) {
          if (value != null && value.toString().isNotEmpty) {
            // Only remove required field error, keep eligibility and other validation errors
            if (fieldErrors[field.key] == 'This field is required') {
              fieldErrors.remove(field.key);
            }
          } else {
            fieldErrors[field.key] = 'This field is required';
          }
        }
      }

      // Check if any other field depends on the changed field
      bool hasDependents = fieldDependencies.values
          .any((deps) => deps.contains(field.key));
      if (hasDependents) {
        _updateFieldVisibility();
      }

      // Notify parent of validation state change
      if (widget.onValidationChanged != null) {
        widget.onValidationChanged!(fieldErrors.isEmpty);
      }
    });

    widget.onChanged(field.key, value);
  }

  // Check if field is an email field
  bool _isEmailField(FormFieldModel field) {
    return field.key.toLowerCase().contains('email') ||
        field.templateOptions['type']?.toString().toLowerCase() == 'email' ||
        field.templateOptions['label']
                ?.toString()
                .toLowerCase()
                .contains('email') ==
            true;
  }

  // Validate email field in real-time
  void _validateEmailField(FormFieldModel field, String value) {
    bool hadErrorsBefore = _hasEmailErrors();

    if (value.isEmpty) {
      // Don't show error for empty field during typing unless required
      if (field.isRequiredForFormData(localFormData)) {
        fieldErrors[field.key] = 'Email is required';
      } else {
        fieldErrors.remove(field.key);
      }
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      fieldErrors[field.key] = 'Please enter a valid email address';
    } else {
      fieldErrors.remove(field.key); // Valid email
    }

    // Notify parent if email validation error state changed
    bool hasErrorsNow = _hasEmailErrors();
    if (hadErrorsBefore != hasErrorsNow &&
        widget.onEmailValidationErrorChanged != null) {
      widget.onEmailValidationErrorChanged!(hasErrorsNow);
    }
  }

  // Check if there are any email validation errors
  bool _hasEmailErrors() {
    List<FormFieldModel> allFields = _getAllFieldsFlat(widget.fields);
    for (var field in allFields) {
      if (_isEmailField(field) && fieldErrors[field.key] != null) {
        return true;
      }
    }
    return false;
  }

  // Check if all form validations pass
  bool isFormValid() {
    // First validate all fields
    _validateAllFields();
    // Return true if there are no field errors
    return fieldErrors.isEmpty;
  }

  // Validate all fields in the form
  void _validateAllFields() {
    List<FormFieldModel> allFields = _getAllFieldsFlat(widget.fields);

    for (var field in allFields) {
      // Skip hidden fields
      if (field.shouldHide(localFormData)) {
        continue;
      }

      dynamic value = localFormData[field.key];
      String valueStr = value?.toString() ?? '';

      // Required field validation
      if (field.isRequiredForFormData(localFormData)) {
        if (value == null || valueStr.isEmpty) {
          // For file fields, check if it's actually a file
          if (field.type == 'file' && value != null) {
            if (!(value is File)) {
              fieldErrors[field.key] = 'This field is required';
              continue;
            }
          } else {
            fieldErrors[field.key] = 'This field is required';
            continue;
          }
        }
      }

      // Skip further validation if field is empty and not required
      if (valueStr.isEmpty && field.type != 'file') {
        fieldErrors.remove(field.key);
        continue;
      }

      // Email validation
      if (_isEmailField(field)) {
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(valueStr)) {
          fieldErrors[field.key] = 'Please enter a valid email address';
          continue;
        }
      }

      // Length validation
      final minLength = field.templateOptions['minLength'];
      final maxLength = field.templateOptions['maxLength'];

      if (minLength != null && valueStr.length < minLength) {
        fieldErrors[field.key] = 'Minimum length is $minLength characters';
        continue;
      }

      if (maxLength != null && valueStr.length > maxLength) {
        fieldErrors[field.key] = 'Maximum length is $maxLength characters';
        continue;
      }

      // Currency/number field validation
      if (field.type == 'currency' ||
          field.templateOptions['type'] == 'currency') {
        final minValue = field.templateOptions['min'] != null
            ? (field.templateOptions['min'] is num
                ? field.templateOptions['min']
                : double.tryParse(field.templateOptions['min'].toString()) ?? 0)
            : 0;
        final maxValue = field.templateOptions['max'] != null
            ? (field.templateOptions['max'] is num
                ? field.templateOptions['max']
                : double.tryParse(field.templateOptions['max'].toString()) ??
                    double.infinity)
            : double.infinity;

        double? amount = double.tryParse(valueStr);
        if (amount != null) {
          if (amount < minValue) {
            fieldErrors[field.key] = 'Minimum amount is KES $minValue';
            continue;
          } else if (amount > maxValue) {
            fieldErrors[field.key] = 'Maximum amount is KES $maxValue';
            continue;
          }
        } else if (valueStr.isNotEmpty) {
          fieldErrors[field.key] = 'Please enter a valid amount';
          continue;
        }
      }

      // Password field validation
      if (field.type == 'password') {
        final expectedLength = field.templateOptions['maxLength'];
        if (expectedLength != null && valueStr.length != expectedLength) {
          fieldErrors[field.key] = 'PIN must be $expectedLength digits';
          continue;
        }
      }

      // Date validation
      if (field.type == 'input' && field.templateOptions['type'] == 'date') {
        if (value is DateTime || (value is String && value.isNotEmpty)) {
          DateTime? date;
          if (value is DateTime) {
            date = value;
          } else if (value is String) {
            try {
              date = DateTime.parse(value);
            } catch (e) {
              fieldErrors[field.key] = 'Invalid date format';
              continue;
            }
          }

          if (date != null) {
            DateTime now = DateTime.now();
            DateTime today = DateTime(now.year, now.month, now.day);
            DateTime selectedDay = DateTime(date.year, date.month, date.day);

            if (selectedDay.isAfter(today)) {
              fieldErrors[field.key] = 'Cannot select a future date';
              continue;
            }
          }
        }
      }

      // Custom validation
      _performCustomValidation(field, value);

      // Date range validation
      if (field.type == 'input' && field.templateOptions['type'] == 'date') {
        _performDateRangeValidation(field, value);
      }
    }

    // Notify parent of validation state change
    if (widget.onValidationChanged != null) {
      widget.onValidationChanged!(fieldErrors.isEmpty);
    }
  }

  // Perform custom validation
  void _performCustomValidation(FormFieldModel field, dynamic value) {
    if (field.validators == null) return;

    Map<String, dynamic> validators = field.validators!;

    if (validators.containsKey('custom')) {
      List<dynamic> customValidators = validators['custom'];

      for (var validator in customValidators) {
        if (validator is Map<String, dynamic>) {
          String validatorName = validator['name'] ?? '';
          String message = validator['message'] ?? 'Validation failed';
          String? expression = validator['expression'];

          if (validatorName == 'notSameAccount' && expression != null) {
            bool isValid =
                _evaluateValidationExpression(expression, localFormData);
            if (!isValid) {
              fieldErrors[field.key] = message;
            }
          }
        }
      }
    }
  }

  // Evaluate validation expressions
  bool _evaluateValidationExpression(
      String expression, Map<String, dynamic> formData) {
    try {
      // Replace model.fieldName with actual values
      String evaluatedExpression = expression;

      RegExp regex = RegExp(r'model\.(\w+)');
      evaluatedExpression =
          evaluatedExpression.replaceAllMapped(regex, (match) {
        String fieldName = match.group(1)!;
        dynamic value = formData[fieldName];

        if (value == null) {
          return 'null';
        } else if (value is String) {
          return "'$value'";
        } else {
          return value.toString();
        }
      });

      // Handle != comparison
      if (evaluatedExpression.contains('!=')) {
        List<String> parts =
            evaluatedExpression.split('!=').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left != right;
        }
      }

      // Default to true if expression cannot be evaluated
      return true;
    } catch (e) {
      AppLogger.error(
          'Error evaluating validation expression: $expression, Error: $e');
      return true; // Default to valid on error
    }
  }

  // Build input formatters
  List<TextInputFormatter> _buildInputFormatters(FormFieldModel field) {
    List<TextInputFormatter> formatters = [];

    String fieldType = field.templateOptions['type'] ?? field.type;

    // Check if this is a phone field and add phone number formatters
    if (_isPhoneField(field) || _hasPhoneKeywords(field)) {
      return PhoneNumberValidator.getPhoneInputFormatters();
    }

    if (fieldType == 'number' ||
        field.templateOptions.containsKey('min') ||
        field.templateOptions.containsKey('max')) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    }

    if (field.templateOptions.containsKey('maxLength')) {
      int? maxLength =
          int.tryParse(field.templateOptions['maxLength'].toString());
      if (maxLength != null) {
        formatters.add(LengthLimitingTextInputFormatter(maxLength));
      }
    }

    return formatters;
  }

  // Perform date range validation
  void _performDateRangeValidation(FormFieldModel field, dynamic value) {
    // Check if this is a date field that should be validated against another date field
    String fieldKey = field.key.toLowerCase();

    // Generic date range validation logic
    if (fieldKey.contains('start') && fieldKey.contains('date')) {
      // This is a start date field, validate against end date
      _validateDateRange(field.key, value, 'start');
    } else if (fieldKey.contains('end') && fieldKey.contains('date')) {
      // This is an end date field, validate against start date
      _validateDateRange(field.key, value, 'end');
    }

    // Also check for other common date field naming patterns
    if (fieldKey == 'startdate' ||
        fieldKey == 'fromdate' ||
        fieldKey == 'datestart') {
      _validateDateRange(field.key, value, 'start');
    } else if (fieldKey == 'enddate' ||
        fieldKey == 'todate' ||
        fieldKey == 'dateend') {
      _validateDateRange(field.key, value, 'end');
    }
  }

  // Validate date range between start and end dates
  void _validateDateRange(
      String currentFieldKey, dynamic currentValue, String fieldType) {
    if (currentValue == null) return;

    DateTime? currentDate;
    if (currentValue is DateTime) {
      currentDate = currentValue;
    } else if (currentValue is String) {
      try {
        currentDate = DateTime.parse(currentValue);
      } catch (e) {
        return; // Invalid date format, let other validation handle it
      }
    } else {
      return;
    }

    if (currentDate == null) return;

    // Find the corresponding date field
    String? otherFieldKey =
        _findCorrespondingDateField(currentFieldKey, fieldType);

    if (otherFieldKey == null) return;

    // Get the other date value
    dynamic otherValue = localFormData[otherFieldKey];
    if (otherValue == null) return;

    DateTime? otherDate;
    if (otherValue is DateTime) {
      otherDate = otherValue;
    } else if (otherValue is String) {
      try {
        otherDate = DateTime.parse(otherValue);
      } catch (e) {
        return; // Invalid date format
      }
    } else {
      return;
    }

    if (otherDate == null) return;

    // Perform validation based on field type
    if (fieldType == 'start') {
      // Current field is start date, check if end date is before start date
      if (otherDate.isBefore(currentDate)) {
        fieldErrors[otherFieldKey] = 'End date cannot be before start date';
      } else {
        // Clear the error if validation passes
        if (fieldErrors[otherFieldKey]
                ?.contains('End date cannot be before start date') ==
            true) {
          fieldErrors.remove(otherFieldKey);
        }
      }
    } else if (fieldType == 'end') {
      // Current field is end date, check if it's before start date
      if (currentDate.isBefore(otherDate)) {
        fieldErrors[currentFieldKey] = 'End date cannot be before start date';
      } else {
        // Clear the error if validation passes
        if (fieldErrors[currentFieldKey]
                ?.contains('End date cannot be before start date') ==
            true) {
          fieldErrors.remove(currentFieldKey);
        }
        // Also clear the other field's error if it exists
        if (fieldErrors[otherFieldKey]
                ?.contains('End date cannot be before start date') ==
            true) {
          fieldErrors.remove(otherFieldKey);
        }
      }
    }
  }

  // Find corresponding date field for range validation
  String? _findCorrespondingDateField(
      String currentFieldKey, String fieldType) {
    currentFieldKey.toLowerCase();

    // Look through all form fields to find the corresponding date field
    List<FormFieldModel> allFields = _getAllFieldsFlat(widget.fields);

    for (FormFieldModel field in allFields) {
      if (field.key == currentFieldKey) continue; // Skip the current field

      String formKeyLower = field.key.toLowerCase();

      // Check if this could be the corresponding date field
      bool isDateField =
          field.type == 'input' && field.templateOptions['type'] == 'date';
      if (!isDateField) continue;

      if (fieldType == 'start') {
        // Looking for end date field
        if (formKeyLower.contains('end') && formKeyLower.contains('date'))
          return field.key;
        if (formKeyLower == 'enddate' ||
            formKeyLower == 'todate' ||
            formKeyLower == 'dateend') return field.key;
      } else if (fieldType == 'end') {
        // Looking for start date field
        if (formKeyLower.contains('start') && formKeyLower.contains('date'))
          return field.key;
        if (formKeyLower == 'startdate' ||
            formKeyLower == 'fromdate' ||
            formKeyLower == 'datestart') return field.key;
      }
    }

    return null;
  }

  Future<void> _checkEligibility(FormFieldModel field) async {
    // Only run eligibility check for AL services (E-loans), not IDL (Digital Loans)
    // IDL has its own button-based eligibility check
    if (widget.serviceCode == 'IDL') {
      return;
    }

    // Get the eloan code from the form data
    String? eloanCode = localFormData['eloanCode']?.toString() ?? localFormData['eLoanCode']?.toString();
    double? amount = double.tryParse(localFormData[field.key]?.toString() ?? '');

    if (eloanCode == null || eloanCode.isEmpty || amount == null || amount <= 0) {
      return;
    }

    setState(() {
      eligibilityCheckLoading[field.key] = true;
      eligibilityMessages.remove(field.key);
    });

    try {
      String? repaymentPeriod = localFormData['repaymentPeriod']?.toString();

      final result = await _eligibilityService.checkEligibility(
        eloanCode: eloanCode,
        amount: amount,
        context: context,
        repaymentPeriod: repaymentPeriod,
      );

      if (mounted) {
        setState(() {
          eligibilityCheckLoading[field.key] = false;

          if (result['success'] == true) {
            bool eligible = result['eligible'] ?? false;
            double eligibleAmount = result['eligibleAmount'] ?? 0;

            eligibleAmounts[field.key] = eligibleAmount;

            if (eligible) {
              eligibilityMessages[field.key] =
                  'Eligible Amount: KES ${NumberFormat('#,##0').format(eligibleAmount)}';
              fieldErrors.remove(field.key);
              // Clear eligibility error flags
              localFormData.remove('_amountEligibilityError');
              localFormData.remove('_eligibleAmount');
            } else {
              eligibilityMessages[field.key] =
                  'You are eligible for KES ${NumberFormat('#,##0').format(eligibleAmount)}';
              fieldErrors[field.key] = 'Sorry: Amount exceeds eligibility limit';
              // Set eligibility error flags for parent to check
              localFormData['_amountEligibilityError'] = true;
              localFormData['_eligibleAmount'] = eligibleAmount;
            }
          } else {
            fieldErrors[field.key] = result['error'] ?? 'Eligibility check failed';
            eligibilityMessages.remove(field.key);
            // Clear eligibility error flags on error
            localFormData.remove('_amountEligibilityError');
            localFormData.remove('_eligibleAmount');
          }

          // Notify parent of validation state change
          if (widget.onValidationChanged != null) {
            widget.onValidationChanged!(fieldErrors.isEmpty);
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error during eligibility check: $e');
      if (mounted) {
        setState(() {
          eligibilityCheckLoading[field.key] = false;
          fieldErrors[field.key] = 'Error checking eligibility';
          // Clear eligibility error flags on error
          localFormData.remove('_amountEligibilityError');
          localFormData.remove('_eligibleAmount');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: _buildFormFields(widget.fields));
  }

  List<Widget> _buildFormFields(List<FormFieldModel> fields) {
    List<Widget> formWidgets = [];

    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        formWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (field.templateOptions.containsKey('label') &&
                  field.templateOptions['label'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    field.templateOptions['label'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      fontFamily:
                          ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ),
              ..._buildFormFields(field.fieldGroup!),
            ],
          ),
        );
        continue;
      }

      if (field.shouldHide(localFormData)) {
        continue;
      }

      Widget fieldWidget;

      // Check for special responseType for Digital Loans display field
      if (field.responseType == 'DIGITALLOANS' && field.type == 'display') {
        // Display field with loan details from eligibility response
        fieldWidget = _buildDigitalLoansDisplayCard(field);
      } else {
        // Normal field type handling
        switch (field.type.toLowerCase()) {
          case 'amounteligibility':
            fieldWidget = _buildLoanAmountField(field);
            break;
          case 'validateguarantor':
            fieldWidget = _buildGuarantorField(field);
            break;
          case 'select':
            fieldWidget = _buildSelectField(field);
            break;
          case 'input':
            if (field.templateOptions['type'] == 'date') {
              fieldWidget = _buildDateField(field);
            } else {
              fieldWidget = _buildInputField(field);
            }
            break;
          case 'currency':
            fieldWidget = _buildCurrencyField(field);
            break;
          case 'password':
            fieldWidget = _buildPasswordField(field);
            break;
          case 'radio':
            fieldWidget = _buildRadioField(field);
            break;
          case 'custombutton':
            if (_isPhoneValidationField(field)) {
              fieldWidget = _buildPhoneValidationField(field);
            } else if (_isContactPickerField(field)) {
              fieldWidget = _buildPhoneField(field);
            } else {
              fieldWidget = _buildInputField(field);
            }
            break;
          case 'display':
            fieldWidget = _buildDisplayField(field);
            break;
          case 'file':
            fieldWidget = _buildFileField(field);
            break;
          case 'array':
            fieldWidget = _buildArrayField(field);
            break;
          case 'repeat':
            fieldWidget = _buildRepeatField(field);
            break;
          default:
            if (field.templateOptions['type'] == 'currency') {
              fieldWidget = _buildCurrencyField(field);
            } else if (field.templateOptions['type'] == 'password') {
              fieldWidget = _buildPasswordField(field);
            } else {
              fieldWidget = _buildInputField(field);
            }
        }
      }

      formWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: fieldWidget,
        ),
      );
    }

    return formWidgets;
  }

  Widget _buildPhoneValidationField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];
    final focusNode = widget.focusNodes?[field.key];
    final validationMessage = widget.validationMessages?[field.key];
    final isLoading = widget.validationLoadingStates?[field.key] ?? false;

    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    // Determine border color based on validation state
    Color getBorderColor() {
      if (errorText != null) return colors.error;
      if (validationMessage != null &&
          validationMessage.contains('Recipient')) {
        return Colors.green;
      }
      return theme.colorScheme.outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        TextField(
          controller: controllers[field.key],
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText:
                field.templateOptions['placeholder'] ?? 'Enter phone number',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: widget.isDarkMode ? Colors.white70 : colors.textSecondary),
            prefixIcon: null,
            suffixIcon: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.contacts, color: colors.primary),
                    onPressed: () => _pickContactForField(field),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: errorText != null ? colors.error : colors.primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? Colors.white : colors.textPrimary),
          keyboardType: TextInputType.phone,
          inputFormatters: PhoneNumberValidator.getPhoneInputFormatters(),
          onChanged: (value) {
            setState(() {
              localFormData[field.key] = value;

              // Clear previous validation messages when user starts typing
              if (validationMessage != null) {
                // Let parent know to clear validation message
                widget.onChanged(field.key, value);
              }

              // Validate field
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
              } else if (value.isNotEmpty &&
                  !PhoneNumberValidator.isValidPhoneNumber(value)) {
                fieldErrors[field.key] =
                    'Please enter a valid Kenyan phone number';
              } else {
                fieldErrors.remove(field.key);
              }
            });

            widget.onChanged(field.key, value);
          },
        ),
        if (validationMessage != null && validationMessage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            validationMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: validationMessage.contains('Recipient')
                  ? Colors.green
                  : Colors.orange,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickContactForField(FormFieldModel field) async {
    try {
      final String? phoneNumber = await ContactPickerUtil.pickContact();
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        String formattedNumber =
            ContactPickerUtil.formatPhoneNumber(phoneNumber);
        controllers[field.key]!.text = formattedNumber;
        setState(() {
          localFormData[field.key] = formattedNumber;

          // Clear any existing errors
          fieldErrors.remove(field.key);
        });

        // Trigger validation by notifying parent
        widget.onChanged(field.key, formattedNumber);

        // Notify parent that a contact was picked (for immediate validation)
        widget.onContactPicked?.call(field.key, formattedNumber);

        AppLogger.info(
            'Contact selected: $formattedNumber for field ${field.key}');
      }
    } catch (e) {
      AppLogger.error('Error picking contact for field ${field.key}: $e');
    }
  }

  bool _isPhoneValidationField(FormFieldModel field) {
    // Check if field has ib_action attribute for validation
    if (field.attributes != null &&
        field.attributes!['ib_action'] == 'validateOtherAccNo') {
      return true;
    }

    // Check if this is the description field in withdrawal service
    if (field.key == 'description' &&
        field.templateOptions.containsKey('attributes') &&
        field.templateOptions['attributes'] is Map &&
        field.templateOptions['attributes'].containsKey('ib_action') &&
        field.templateOptions['attributes']['ib_action'] ==
            'validateOtherAccNo') {
      return true;
    }

    if (_isPhoneField(field) || _hasPhoneKeywords(field)) {
      return true;
    }

    return false;
  }

  Widget _buildSelectField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final options = field.templateOptions['options'] ?? [];
    final errorText = fieldErrors[field.key];

    // Auto-select if there's only one option and nothing is selected yet
    if (options.length == 1 && localFormData[field.key] == null) {
      final singleOption = options[0];
      final autoValue = singleOption['id']?.toString() ?? singleOption['key']?.toString() ?? singleOption['value']?.toString();
      if (autoValue != null && autoValue.isNotEmpty) {
        // Schedule auto-selection after the current build frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && localFormData[field.key] == null) {
            setState(() {
              localFormData[field.key] = autoValue;
              fieldErrors.remove(field.key);
            });
            widget.onChanged(field.key, autoValue);
            if (widget.onValidationChanged != null) {
              widget.onValidationChanged!(fieldErrors.isEmpty);
            }
          }
        });
      }
    }

    // If there's only one option and it's auto-selected, show a styled selected field
    if (options.length == 1 && localFormData[field.key] != null) {
      final selectedOption = options[0];
      final displayText = selectedOption['label']?.toString() ??
          selectedOption['name']?.toString() ??
          selectedOption['value']?.toString() ??
          '';
      final bool isLockedByCarousel = widget.lockedFieldKeys != null && widget.lockedFieldKeys!.isNotEmpty;
      final String subtitleText = isLockedByCarousel
          ? 'Pre-selected from your account card'
          : 'Auto-selected (only eligible account available for this transaction)';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired, theme),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: isLockedByCarousel ? widget.onLockedFieldTapped : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: colors.primary.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(10.0),
                color: widget.isDarkMode ? Colors.grey[800] : (theme.brightness == Brightness.dark
                    ? colors.surface
                    : colors.primary.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Icon(
                    isLockedByCarousel ? Icons.lock_outline : Icons.account_balance_wallet,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.isDarkMode ? Colors.white : colors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.isDarkMode ? Colors.white70 : (theme.brightness == Brightness.dark
                                ? colors.textPrimary.withValues(alpha: 0.7)
                                : colors.textSecondary),
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                      ],
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: colors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                errorText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.error,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
        ],
      );
    }

    // Check if an account is already selected
    final selectedValue = localFormData[field.key] as String?;
    Map<String, dynamic>? selectedOption;
    if (selectedValue != null) {
      for (var opt in options) {
        final optVal = opt['id']?.toString() ?? opt['key']?.toString() ?? opt['value']?.toString();
        if (optVal == selectedValue) {
          selectedOption = Map<String, dynamic>.from(opt);
          break;
        }
      }
    }

    // If an account is selected, show styled container with change option
    if (selectedOption != null) {
      final displayText = selectedOption['name']?.toString() ??
          selectedOption['label']?.toString() ??
          selectedOption['value']?.toString() ??
          '';
      final balance = selectedOption['balance'];
      final hasBalance = balance != null && balance is num && balance > 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired, theme),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => _showAccountSelectionSheet(field, options, theme),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: colors.primary.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(10.0),
                color: widget.isDarkMode ? Colors.grey[800] : (theme.brightness == Brightness.dark
                    ? colors.surface
                    : colors.primary.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.isDarkMode ? Colors.white : colors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                        if (hasBalance) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Bal: KES ${NumberFormat('#,##0.00').format(balance)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.isDarkMode ? Colors.white70 : (theme.brightness == Brightness.dark
                                  ? colors.textPrimary.withValues(alpha: 0.7)
                                  : colors.textSecondary),
                              fontFamily: ClientThemeManager()
                                  .currentClientConfig
                                  .fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                errorText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.error,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
        ],
      );
    }

    // No account selected — show tap-to-select container
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _showAccountSelectionSheet(field, options, theme),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(10.0),
              color: widget.isDarkMode ? Colors.grey[800] : colors.surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select an option',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: widget.isDarkMode ? Colors.white54 : colors.textSecondary,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: colors.textSecondary),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontFamily:
                    ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  void _showAccountSelectionSheet(FormFieldModel field, List<dynamic> options, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    field.templateOptions['label'] ?? 'Select Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final optionValue = option['id']?.toString() ?? option['key']?.toString() ?? option['value']?.toString();
                      final accountName = option['name']?.toString() ??
                          option['label']?.toString() ??
                          option['value']?.toString() ??
                          '';
                      final balance = option['balance'];
                      final hasBalance = balance != null && balance is num && balance > 0;
                      final isSelected = localFormData[field.key] == optionValue;

                      return ListTile(
                        leading: Icon(
                          Icons.account_balance_wallet,
                          color: isSelected ? colors.primary : (widget.isDarkMode ? Colors.white54 : Colors.grey[600]),
                        ),
                        title: Text(
                          accountName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.isDarkMode ? Colors.white : colors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                          ),
                        ),
                        subtitle: hasBalance
                            ? Text(
                                'Bal: KES ${NumberFormat('#,##0.00').format(balance)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: widget.isDarkMode ? Colors.white70 : colors.textSecondary,
                                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: colors.primary, size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            localFormData[field.key] = optionValue;
                            final isRequired = field.isRequiredForFormData(localFormData);
                            if (isRequired && (optionValue == null || optionValue.isEmpty)) {
                              fieldErrors[field.key] = 'This field is required';
                            } else {
                              fieldErrors.remove(field.key);
                            }
                          });
                          _handleFieldChange(field, optionValue);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDisplayField(FormFieldModel field) {
    final theme = Theme.of(context);
    final displayType = field.templateOptions['displayType'] ?? 'text';

    AppLogger.info('_buildDisplayField called - key: ${field.key}, type: ${field.type}, responseType: ${field.responseType}');

    // Handle Digital Loans display field (Screen 2 header for IDL)
    if (field.responseType == 'DIGITALLOANS') {
      AppLogger.info('Matched DIGITALLOANS responseType - building display card');
      return _buildDigitalLoansDisplayCard(field);
    } else {
      AppLogger.info('Not Matched DIGITALLOANS responseType: Current responseType is: ${field.responseType}');
    }

    // Handle product info display (Screen 2 header for IDL)
    if (displayType == 'productInfo') {
      return _buildProductInfoCard(field);
    }

    // Handle calculated fields (e.g., guarantors pending)
    if (field.templateOptions.containsKey('calculation')) {
      return _buildCalculatedDisplayField(field);
    }

    // Default display field (simple text)
    final text = field.templateOptions['text'] ?? '';

    if (text.isEmpty) {
      return const SizedBox.shrink(); // Return empty widget if no text
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
          fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
        ),
      ),
    );
  }

  /// Build Digital Loans display card with label-value rows
  /// Displays fields in the order defined in the journey configuration (stored in _keyOrder)
  Widget _buildDigitalLoansDisplayCard(FormFieldModel field) {
    final theme = Theme.of(context);
    final templateOptions = field.templateOptions;

    List<String> _normalizeKeyOrder(dynamic raw, Map templateOptions) {
      if (raw == null) {
        return templateOptions.keys.map((e) => e.toString()).toList();
      }
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty) return templateOptions.keys.map((e) => e.toString()).toList();
        if ((s.startsWith('[') && s.endsWith(']')) ||
            (s.startsWith('{') && s.endsWith('}'))) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              return decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {
            // ignore and fall back to comma split below
          }
        }
        if (s.contains(',')) {
          return s
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return <String>[s];
      }
      return templateOptions.keys.map((e) => e.toString()).toList();
    }

    final List<String> keyOrder =
    _normalizeKeyOrder(templateOptions['_keyOrder'], templateOptions);
    AppLogger.info('Building Digital Loans display card. Using key order: $keyOrder');

    const skipKeys = {'fetchUrl', 'displayData', 'options', 'orderedDisplayData', '_keyOrder'};
    const guarantorKeys = {'guarantorRequired', 'guarantorPending'};
    const hardcodedKeys = {'amt', 'repaymentPeriod', 'maxEligibleAmount'};

    // Main product display card rows data
    final mainDisplayRows = <Map<String, String>>[];
    // 1. Hardcoded 1st key: Amount Applied
    final amtValue = widget.formData['amt'];
    if (amtValue != null && amtValue.toString().isNotEmpty) {
      String formattedAmt = amtValue.toString();
      final numValue = num.tryParse(formattedAmt);
      if (numValue != null) {
        formattedAmt = numValue.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
      }
      String displayValue = 'Ksh. $formattedAmt';
      mainDisplayRows.add({'label': 'Amount Applied', 'value': displayValue});
    }

    // 2. Hardcoded 2nd key: Repayment Period
    final repaymentValue = widget.formData['repaymentPeriod'];
    if (repaymentValue != null && repaymentValue.toString().isNotEmpty) {
      String periodStr = repaymentValue.toString();
      final periodNum = num.tryParse(periodStr);
      String displayPeriod;
      if (periodNum != null) {
        displayPeriod = periodNum == 1 ? '$periodStr Month' : '$periodStr Months';
      } else {
        displayPeriod = periodStr;
      }
      mainDisplayRows.add({'label': 'Repayment Period', 'value': displayPeriod});
    }

    // 3. Other dynamic fields follows
    for (final key in keyOrder) {
      if (skipKeys.contains(key)) continue;
      // Skip guarantor keys - they have their own display section below
      if (guarantorKeys.contains(key)) continue;
      // Skip productName - it's displayed as the card title
      if (key == 'productName') continue;
      // Skip hardcoded keys (already added above) and maxEligibleAmount (removed entirely)
      if (hardcodedKeys.contains(key)) continue;

      final value = templateOptions[key];
      if (value == null || value.toString().isEmpty) continue;

      String valueStr = value.toString();

      AppLogger.info('Display field key: $key, value: $valueStr');

      // Skip if still contains unfilled placeholders
      if (valueStr.contains('<')) {
        AppLogger.info('Skipping $key - contains placeholder');
        continue;
      }

      // Parse the string to extract label and value (format: "Label: Value")
      final colonIndex = valueStr.indexOf(':');
      if (colonIndex > 0) {
        final label = valueStr.substring(0, colonIndex).trim();
        var displayValue = valueStr.substring(colonIndex + 1).trim();

        mainDisplayRows.add({'label': label, 'value': displayValue});
      }
    }

    AppLogger.info('Total display rows built: ${mainDisplayRows.length}');

    // Build guarantor info card data
    final guarantorInfoRows = <Map<String, String>>[];
    for (final key in guarantorKeys) {
      final value = templateOptions[key];
      if (value == null || value.toString().isEmpty) continue;

      String valueStr = value.toString();
      if (valueStr.contains('<')) continue; // Skip unfilled placeholders

      final colonIndex = valueStr.indexOf(':');
      if (colonIndex > 0) {
        final label = valueStr.substring(0, colonIndex).trim();
        final displayValue = valueStr.substring(colonIndex + 1).trim();
        guarantorInfoRows.add({'label': label, 'value': displayValue});
      }
    }

    // If both main card and guarantor card are empty, return empty widget
    if (mainDisplayRows.isEmpty && guarantorInfoRows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract productName for the card title (from templateOptions)
    String cardTitle = 'Loan Details'; // fallback
    final productNameValue = templateOptions['productName'];
    if (productNameValue != null && productNameValue.toString().isNotEmpty) {
      final valueStr = productNameValue.toString();
      final colonIndex = valueStr.indexOf(':');
      if (colonIndex > 0) {
        cardTitle = valueStr.substring(colonIndex + 1).trim();
      }
    }

    final mainCard = mainDisplayRows.isEmpty
        ? const SizedBox.shrink()
        : _buildLoanDetailsCard(mainDisplayRows, theme, cardTitle);

    final guarantorCard = guarantorInfoRows.isEmpty
        ? const SizedBox.shrink()
        : _buildGuarantorInfoCard(guarantorInfoRows, theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mainCard,
        guarantorCard,
      ],
    );
  }

  /// Main loan details display card
  Widget _buildLoanDetailsCard(List<Map<String, String>> rows, ThemeData theme, String title) {
    final isDark = widget.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          // Header -> product name
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows with border separators
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isLast = index == rows.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row['label']!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row['value']!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// GuarantorRequired and guarantorPending display card
  Widget _buildGuarantorInfoCard(List<Map<String, String>> rows, ThemeData theme) {
    final isDark = widget.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Guarantor Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isLast = index == rows.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      row['label']!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row['value']!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Build product info card for IDL Screen 2
  Widget _buildProductInfoCard(FormFieldModel field) {
    // Extract values from formData
    String productName = localFormData['productName']?.toString() ?? 'Digital Loan';
    String loanAmount = localFormData['amt']?.toString() ?? '0';
    String repaymentPeriod = localFormData['repaymentPeriod']?.toString() ?? 'N/A';
    int guarantorsRequired = localFormData['guarantorsCount'] ?? 0;
    List<dynamic> guarantors = localFormData['guarantors'] ?? [];
    int guarantorsPending = guarantorsRequired - guarantors.where((g) => g != null && (g as Map).isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary.withOpacity(0.1), colors.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Loan Amount', 'KES $loanAmount'),
          const SizedBox(height: 8),
          _buildInfoRow('Repayment Period', '$repaymentPeriod ${int.tryParse(repaymentPeriod) == 1 ? "month" : "months"}'),
          const SizedBox(height: 8),
          _buildInfoRow('Guarantors Required', guarantorsRequired.toString()),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Guarantors Pending',
            guarantorsPending.toString(),
            valueColor: guarantorsPending > 0 ? Colors.orange : Colors.green,
          ),
        ],
      ),
    );
  }

  /// Helper to build info rows in product card
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
      ],
    );
  }

  /// Build calculated display field
  Widget _buildCalculatedDisplayField(FormFieldModel field) {
    String calculation = field.templateOptions['calculation'] ?? '';
    dynamic calculatedValue;

    // Parse calculation expression
    // Example: "model.guarantorsCount - model.guarantors.length"
    if (calculation.contains('model.')) {
      try {
        // Simple calculation parser
        String expression = calculation;

        // Replace model.fieldName with actual values
        RegExp regex = RegExp(r'model\.(\w+)(?:\.(\w+))?');
        expression = expression.replaceAllMapped(regex, (match) {
          String fieldName = match.group(1)!;
          String? property = match.group(2);

          dynamic value = localFormData[fieldName];

          if (property == 'length' && value is List) {
            return value.length.toString();
          }

          return value?.toString() ?? '0';
        });

        // Evaluate simple arithmetic (just subtraction for now)
        if (expression.contains('-')) {
          List<String> parts = expression.split('-');
          if (parts.length == 2) {
            int left = int.tryParse(parts[0].trim()) ?? 0;
            int right = int.tryParse(parts[1].trim()) ?? 0;
            calculatedValue = left - right;
          }
        }
      } catch (e) {
        AppLogger.error('Error calculating field value: $e');
        calculatedValue = 'Error';
      }
    }

    final label = field.templateOptions['label'] ?? field.key;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
          Text(
            calculatedValue?.toString() ?? 'N/A',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final isNumber = field.templateOptions['type'] == 'number';
    final isEmail = _isEmailField(field);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];

    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    // Determine border color based on validation state
    Color getBorderColor() {
      if (errorText != null) return colors.error;
      return theme.colorScheme.outline;
    }

    // Get suffix icon for validation feedback
    Widget? getSuffixIcon() {
      if (errorText != null) {
        return Icon(
          Icons.error,
          color: colors.error,
        );
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        TextField(
          controller: controllers[field.key],
          decoration: InputDecoration(
            hintText: field.templateOptions['placeholder'] ??
                (label.toLowerCase().startsWith('enter') ? 'Enter ${label.substring(5).toLowerCase().trim()}'
                    : 'Enter ${label.toLowerCase()}'),
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: widget.isDarkMode ? Colors.white70 : colors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                  color: errorText != null ? colors.error : colors.primary,
                  width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
            suffixIcon: getSuffixIcon(),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? Colors.white : colors.textPrimary),
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : ((_isPhoneField(field) || _hasPhoneKeywords(field))
                  ? TextInputType.phone
                  : (isNumber ? TextInputType.number : TextInputType.text)),
          inputFormatters: _buildInputFormatters(field),
          onChanged: (value) {
            // Enhanced validation with min/max length, phone validation, and numeric ranges
            setState(() {
              localFormData[field.key] = value;

              // Check if this is a phone field
              final isPhoneField =
                  _isPhoneField(field) || _hasPhoneKeywords(field);

              // Get minLength and maxLength from templateOptions
              final minLengthValue = field.templateOptions['minLength'];
              final maxLengthValue = field.templateOptions['maxLength'];

              // Get min and max values for numeric fields from templateOptions
              final minValue = field.templateOptions['min'] != null
                  ? (field.templateOptions['min'] is num
                      ? field.templateOptions['min']
                      : double.tryParse(field.templateOptions['min'].toString()) ?? 0)
                  : null;
              final maxValue = field.templateOptions['max'] != null
                  ? (field.templateOptions['max'] is num
                      ? field.templateOptions['max']
                      : double.tryParse(field.templateOptions['max'].toString()) ?? null)
                  : null;

              // Validate field
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
              } else if (isPhoneField &&
                  value.isNotEmpty &&
                  !PhoneNumberValidator.isValidPhoneNumber(value)) {
                fieldErrors[field.key] =
                    'Please enter a valid Kenyan phone number';
              } else if (minLengthValue != null &&
                  value.length < minLengthValue) {
                fieldErrors[field.key] =
                    'Minimum length is $minLengthValue characters';
              } else if (maxLengthValue != null &&
                  value.length > maxLengthValue) {
                fieldErrors[field.key] =
                    'Maximum length is $maxLengthValue characters';
              } else if (isNumber && value.isNotEmpty) {
                // Numeric range validation for number fields
                double? numValue = double.tryParse(value);
                if (numValue != null) {
                  if (minValue != null && numValue < minValue) {
                    fieldErrors[field.key] = 'Minimum value is ${minValue.toInt()}';
                  } else if (maxValue != null && numValue > maxValue) {
                    fieldErrors[field.key] = 'Maximum value is ${maxValue.toInt()}';
                  } else {
                    fieldErrors.remove(field.key);
                  }
                } else {
                  fieldErrors[field.key] = 'Please enter a valid number';
                }
              } else {
                // Clear validation errors
                if (!isEmail) {
                  // Let email validation handle its own validation
                  fieldErrors.remove(field.key);
                }
              }
            });

            final dynamic parsedValue;
            if (isNumber && value.isNotEmpty) {
              final intValue = int.tryParse(value);
              if (intValue != null) {
                parsedValue = intValue;
              } else {
                parsedValue = double.tryParse(value) ?? value;
              }
            } else {
              parsedValue = value;
            }
            _handleFieldChange(field, parsedValue);
          },
        ),
      ],
    );
  }

  Widget _buildCurrencyField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];
    final minValue = field.templateOptions['min'] != null
        ? (field.templateOptions['min'] is num
            ? field.templateOptions['min']
            : double.tryParse(field.templateOptions['min'].toString()) ?? 0)
        : 0;
    final maxValue = field.templateOptions['max'] != null
        ? (field.templateOptions['max'] is num
            ? field.templateOptions['max']
            : double.tryParse(field.templateOptions['max'].toString()) ??
                double.infinity)
        : double.infinity;

    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    // Get border color based on validation state
    Color getBorderColor() {
      if (errorText != null) return colors.error;
      return theme.colorScheme.outline;
    }

    // Get suffix icon for validation feedback
    Widget? getSuffixIcon() {
      if (errorText != null) {
        return Icon(Icons.error, color: colors.error);
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        TextField(
          controller: controllers[field.key],
          decoration: InputDecoration(
            hintText: 'Enter amount',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: widget.isDarkMode ? Colors.white70 : colors.textSecondary),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                'KES',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : ColorPalette.fontColor,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
            suffixIcon: getSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: errorText != null ? colors.error : colors.primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? Colors.white : colors.textPrimary),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            // Enhanced currency validation
            setState(() {
              localFormData[field.key] = value;

              // Validate field
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
              } else if (value.isNotEmpty) {
                // Only perform numeric validation if value is not empty
                double? amount = double.tryParse(value);
                if (amount != null) {
                  // Check min and max constraints only if valid number
                  if (amount < minValue) {
                    fieldErrors[field.key] = 'Minimum amount is KES $minValue';
                  } else if (amount > maxValue) {
                    fieldErrors[field.key] = 'Maximum amount is KES $maxValue';
                  } else {
                    fieldErrors.remove(field.key);
                  }
                } else {
                  // Not a valid number but has content
                  fieldErrors[field.key] = 'Please enter a valid amount';
                }
              } else {
                fieldErrors.remove(field.key);
              }
            });

            _handleFieldChange(field, value);
          },
        ),
      ],
    );
  }

  Widget _buildAmountEligibilityField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];
    final minValue = field.templateOptions['min'] != null
        ? (field.templateOptions['min'] is num
            ? field.templateOptions['min']
            : double.tryParse(field.templateOptions['min'].toString()) ?? 0)
        : 0;
    final maxValue = field.templateOptions['max'] != null
        ? (field.templateOptions['max'] is num
            ? field.templateOptions['max']
            : double.tryParse(field.templateOptions['max'].toString()) ??
                double.infinity)
        : double.infinity;
    final isLoading = eligibilityCheckLoading[field.key] ?? false;
    final eligibilityMessage = eligibilityMessages[field.key];

    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    // Create or get FocusNode for this field
    FocusNode fieldFocusNode = widget.focusNodes?[field.key] ?? FocusNode();

    // Add listener for focus changes to check eligibility on blur (only once)
    if (!(_focusNodeListenerSetup[field.key] ?? false)) {
      fieldFocusNode.addListener(() {
        if (!fieldFocusNode.hasFocus && controllers[field.key]!.text.isNotEmpty) {
          _checkEligibility(field);
        }
      });
      _focusNodeListenerSetup[field.key] = true;
    }

    // Determine border color based on validation state
    Color getBorderColor() {
      if (errorText != null) return colors.error;
      return theme.colorScheme.outline;
    }

    // Get suffix icon for validation/loading feedback
    Widget? getSuffixIcon() {
      if (isLoading) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        );
      }
      if (errorText != null) {
        return Icon(Icons.error, color: colors.error);
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        TextField(
          controller: controllers[field.key],
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            hintText: 'Enter amount',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: widget.isDarkMode ? Colors.white70 : colors.textSecondary),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                'KES',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : ColorPalette.fontColor,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
            suffixIcon: getSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: errorText != null ? colors.error : colors.primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? Colors.white : colors.textPrimary),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            setState(() {
              localFormData[field.key] = value;

              // Validate field
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
                // Clear eligibility messages and flags when field is cleared
                eligibilityMessages.remove(field.key);
                eligibilityCheckLoading.remove(field.key);
                localFormData.remove('_amountEligibilityError');
                localFormData.remove('_eligibleAmount');
              } else if (value.isNotEmpty) {
                double? amount = double.tryParse(value);
                if (amount != null) {
                  if (amount < minValue) {
                    fieldErrors[field.key] = 'Minimum amount is KES $minValue';
                    // Clear eligibility messages when field has validation error
                    eligibilityMessages.remove(field.key);
                    localFormData.remove('_amountEligibilityError');
                    localFormData.remove('_eligibleAmount');
                  } else if (amount > maxValue) {
                    fieldErrors[field.key] = 'Maximum amount is KES $maxValue';
                    // Clear eligibility messages when field has validation error
                    eligibilityMessages.remove(field.key);
                    localFormData.remove('_amountEligibilityError');
                    localFormData.remove('_eligibleAmount');
                  } else {
                    fieldErrors.remove(field.key);
                  }
                } else {
                  fieldErrors[field.key] = 'Please enter a valid amount';
                  // Clear eligibility messages when field has validation error
                  eligibilityMessages.remove(field.key);
                  localFormData.remove('_amountEligibilityError');
                  localFormData.remove('_eligibleAmount');
                }
              } else {
                fieldErrors.remove(field.key);
                // Clear eligibility messages and flags when field is cleared
                eligibilityMessages.remove(field.key);
                eligibilityCheckLoading.remove(field.key);
                localFormData.remove('_amountEligibilityError');
                localFormData.remove('_eligibleAmount');
              }
            });

            _handleFieldChange(field, value);
          },
        ),
        if (eligibilityMessage != null && eligibilityMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              eligibilityMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorText != null ? colors.error : Colors.green,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];
    final maxLength = field.templateOptions['maxLength'] != null
        ? int.tryParse(field.templateOptions['maxLength'].toString())
        : null;

    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        TextField(
          controller: controllers[field.key],
          obscureText: true,
          decoration: InputDecoration(
            hintText: label.toLowerCase().startsWith('enter') ? 'Enter ${label.substring(5).toLowerCase().trim()}'
                : 'Enter ${label.toLowerCase()}',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: widget.isDarkMode ? Colors.white70 : colors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.secondary, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? Colors.white : colors.textPrimary),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          onChanged: (value) {
            // Enhanced password validation
            setState(() {
              localFormData[field.key] = value;

              // Validate field
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
              } else if (maxLength != null && value.length > maxLength) {
                fieldErrors[field.key] = 'Maximum length is $maxLength';
              } else if (maxLength != null &&
                  value.length < maxLength &&
                  value.isNotEmpty) {
                fieldErrors[field.key] = 'PIN must be $maxLength digits';
              } else {
                fieldErrors.remove(field.key);
              }
            });

            _handleFieldChange(field, value);
          },
        ),
      ],
    );
  }

  Widget _buildRadioField(FormFieldModel field) {
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? field.key;
    final options = field.templateOptions['options'] ?? [];
    final theme = Theme.of(context);
    final errorText = fieldErrors[field.key];
    final isLocked = widget.lockedFieldKeys?.contains(field.key) ?? false;

    if (options.isEmpty) {
      return Text('No options available for $label');
    }

    String? currentValue = localFormData[field.key]?.toString();

    // If locked, show a read-only styled display of the selected value
    if (isLocked && currentValue != null) {
      // Find the label for the current value
      String selectedLabel = currentValue;
      for (var option in options) {
        final optKey = option['key']?.toString() ?? option['value']?.toString() ?? '';
        if (optKey == currentValue) {
          selectedLabel = option['value']?.toString() ?? option['label']?.toString() ?? optKey;
          break;
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired, theme),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onLockedFieldTapped,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: (widget.isDarkMode ? Colors.grey[800] : colors.surface),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: theme.colorScheme.outline, width: 1.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedLabel,
                      style: TextStyle(
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: currentValue,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                localFormData[field.key] = value;

                if (isRequired && (value.isEmpty)) {
                  fieldErrors[field.key] = 'This field is required';
                } else {
                  fieldErrors.remove(field.key);
                }
              });

              _handleFieldChange(field, value);
            }
          },
          items: options.map<DropdownMenuItem<String>>((option) {
            final String optionValue = option['key']?.toString() ??
                option['value']?.toString() ??
                option['id']?.toString() ??
                '';
            final String optionLabel = option['value']?.toString() ??
                option['label']?.toString() ??
                option['name']?.toString() ??
                optionValue;

            return DropdownMenuItem<String>(
              value: optionValue,
              child: Text(
                optionLabel,
                style: TextStyle(
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.secondary, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.error),
            ),
            errorText: errorText,
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : colors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            hintText: 'Select an option',
          ),
          hint: Text(
            'Select an option',
            style: TextStyle(
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDateField(FormFieldModel field) {
    final theme = Theme.of(context);
    final isRequired = field.isRequiredForFormData(localFormData);
    final label = field.templateOptions['label'] ?? '';
    final errorText = fieldErrors[field.key];

    DateTime? selectedDate;
    if (localFormData[field.key] != null) {
      if (localFormData[field.key] is DateTime) {
        selectedDate = localFormData[field.key];
      } else if (localFormData[field.key] is String) {
        try {
          selectedDate = DateTime.parse(localFormData[field.key]);
        } catch (e) {
          selectedDate = null;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 5),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme:
                        theme.colorScheme.copyWith(primary: colors.primary),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null) {
              setState(() {
                localFormData[field.key] = pickedDate;

                // Validate date - check for future dates (basic validation)
                DateTime now = DateTime.now();
                DateTime today = DateTime(now.year, now.month, now.day);
                DateTime selectedDay =
                    DateTime(pickedDate.year, pickedDate.month, pickedDate.day);

                if (selectedDay.isAfter(today)) {
                  fieldErrors[field.key] = 'Cannot select a future date';
                } else {
                  if (fieldErrors[field.key] == 'Cannot select a future date' ||
                      fieldErrors[field.key] == 'This field is required') {
                    fieldErrors.remove(field.key);
                  }
                }
              });

              // Only notify parent if date is valid
              DateTime now = DateTime.now();
              DateTime today = DateTime(now.year, now.month, now.day);
              DateTime selectedDay =
                  DateTime(pickedDate.year, pickedDate.month, pickedDate.day);

              if (!selectedDay.isAfter(today)) {
                _handleFieldChange(field, pickedDate);
              }
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: errorText != null
                    ? colors.error
                    : theme.colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(10.0),
              color: widget.isDarkMode ? Colors.grey[800] : colors.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate == null
                      ? 'Select Date'
                      : DateFormat('MM-dd-yyyy').format(selectedDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selectedDate == null
                        ? (widget.isDarkMode ? Colors.white70 : colors.textSecondary)
                        : (widget.isDarkMode ? Colors.white : colors.textPrimary),
                    fontFamily:
                        ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
                Icon(Icons.calendar_today,
                    color: colors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isRequired, ThemeData theme) {
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: widget.isDarkMode ? Colors.white : colors.textSecondary,
            fontWeight: FontWeight.bold,
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.bold,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
      ],
    );
  }

  Widget _buildLoanAmountField(FormFieldModel field) {
    final minAmount = _toDouble(
      field.templateOptions['min'],
      // defaultValue: 100,
    );

    final maxAmount = _toDouble(
      field.templateOptions['max'],
      // defaultValue: 100000,
    );

    // Get repayment period from formData
    String? repaymentPeriod = localFormData['repaymentPeriod']?.toString();

    // Get eloanCode: prioritize formData (for AL services), fallback to widget (for IDL)
    String? eloanCode = localFormData['eloanCode']?.toString() ?? localFormData['eLoanCode']?.toString() ?? widget.eloanCode;

    AppLogger.info('Building LoanAmountField with eloanCode: $eloanCode');

    return LoanAmountField(
      label: field.templateOptions['label'] ?? 'Loan Amount',
      isRequired: field.isRequiredForFormData(localFormData),
      minAmount: minAmount,
      maxAmount: maxAmount,
      initialValue: localFormData[field.key]?.toString(),
      repaymentPeriod: repaymentPeriod,
      eloanCode: eloanCode,
      serviceCode: widget.serviceCode,
      onChanged: (value) {
        _handleFieldChange(field, value);
      },
      onEligibilityChecked: (error) {
        setState(() {
          if (error != null) {
            fieldErrors[field.key] = error;
          } else {
            fieldErrors.remove(field.key);
          }
        });
        // Notify parent of validation state change so submit button updates
        if (widget.onValidationChanged != null) {
          widget.onValidationChanged!(fieldErrors.isEmpty);
        }
      },
      onGuarantorsCountReceived: (count) {
        setState(() {
          _guarantorCountNeeded = count;
          AppLogger.info('Guarantor count updated: $count');

          // Initialize guarantors array in formData if needed
          if (count > 0 && !localFormData.containsKey('guarantors')) {
            localFormData['guarantors'] = List.generate(
              count,
              (index) => <String, dynamic>{},
            );
          } else if (count > 0) {
            // Update existing guarantors array to match the count
            List<dynamic> existingGuarantors = List.from(localFormData['guarantors'] ?? []);
            if (existingGuarantors.length < count) {
              // Add more guarantor slots
              for (int i = existingGuarantors.length; i < count; i++) {
                existingGuarantors.add(<String, dynamic>{});
              }
            } else if (existingGuarantors.length > count) {
              // Remove extra guarantor slots
              existingGuarantors = existingGuarantors.sublist(0, count);
            }
            localFormData['guarantors'] = existingGuarantors;
          }

          // Notify parent widget of the change
          widget.onChanged('guarantors', localFormData['guarantors']);
        });
      },
    );
  }

  double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return defaultValue;
      final parsed = double.tryParse(trimmed);
      if (parsed != null) return parsed.toDouble();
    }

    return defaultValue;
  }

// Build guarantor validation field
  Widget _buildGuarantorField(FormFieldModel field) {
    return GuarantorField(
      label: field.templateOptions['label'] ?? 'Guarantor Phone',
      isRequired: field.isRequiredForFormData(localFormData),
      initialValue: localFormData[field.key]?.toString(),
      formData: localFormData,
      onChanged: (value) {
        _handleFieldChange(field, value);
      },
      onValidated: (isValid, message) {
        setState(() {
          if (!isValid && message != null) {
            fieldErrors[field.key] = message;
          } else {
            fieldErrors.remove(field.key);
          }

          // If we need more guarantors, the parent should handle adding fields
          // This would require a callback to the form journey screen
        });
      },
    );
  }

// Build repeat field for dynamic guarantor arrays
  Widget _buildRepeatField(FormFieldModel field) {
    // Check if this is for guarantors based on field structure
    if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
      final hasGuarantorValidation = field.fieldArray!
          .any((f) => f.type.toLowerCase() == 'validateguarantor');

      if (hasGuarantorValidation) {
        return _buildGuarantorRepeatField(field);
      }
    }

    // Default array field behavior
    return _buildArrayField(field);
  }

// Build guarantor repeat field
  Widget _buildGuarantorRepeatField(FormFieldModel field) {
    final label = field.templateOptions['label'] ?? field.key;
    final isRequired = field.isRequiredForFormData(localFormData);
    final theme = Theme.of(context);

    // Get current guarantors array and ensure it matches the required count
    List<dynamic> guarantors = localFormData[field.key] ?? [];

    // If we have a guarantor count requirement, ensure the array has that many slots
    if (_guarantorCountNeeded > 0) {
      if (guarantors.length < _guarantorCountNeeded) {
        // Add missing guarantor slots
        for (int i = guarantors.length; i < _guarantorCountNeeded; i++) {
          guarantors.add(<String, dynamic>{});
        }
        localFormData[field.key] = guarantors;
      } else if (guarantors.length > _guarantorCountNeeded) {
        // Remove extra guarantor slots
        guarantors = guarantors.sublist(0, _guarantorCountNeeded);
        localFormData[field.key] = guarantors;
      }
    }

    // If no guarantors are needed yet, show a message
    if (_guarantorCountNeeded == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enter loan amount applying for to determine guarantor requirements',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel(label, isRequired, theme),
            // TextButton.icon(
            //   icon: Icon(Icons.add, color: colors.primary, size: 20),
            //   label: Text(
            //     'Add Guarantor',
            //     style: TextStyle(
            //       color: colors.primary,
            //       fontSize: 14,
            //       fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            //     ),
            //   ),
            //   onPressed: () {
            //     setState(() {
            //       List<dynamic> updatedGuarantors = List.from(guarantors);
            //       updatedGuarantors.add({});
            //       localFormData[field.key] = updatedGuarantors;
            //     });
            //   },
            // ),
          ],
        ),
        const SizedBox(height: 12),

        // Display guarantor fields or validation loader
        if (_isValidatingGuarantor) ...[
          // Show loader when validating a guarantor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: colors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
              color: colors.primary.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Validating Guarantor...',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (guarantors.isEmpty && !_isValidatingGuarantor) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[50],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'No guarantors added yet',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          for (int i = 0; i < guarantors.length; i++) ...[
            _buildGuarantorItem(field, i, guarantors[i]),
            if (i < guarantors.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildGuarantorItem(FormFieldModel parentField, int index, dynamic guarantorData) {
    Map<String, dynamic> guarantor = guarantorData is Map<String, dynamic>
        ? guarantorData
        : {};

    // Check if this guarantor is validated
    bool isValidated = guarantor['isValidated'] == true;

    // If validated, show guarantor details card
    if (isValidated) {
      String guarantorName = guarantor['guarantorName']?.toString() ?? '';
      String guarantorPhone = guarantor['guarantorPhone']?.toString() ?? '';
      String amountToGuarantee = guarantor['amountToGuarantee']?.toString() ?? '';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: widget.isDarkMode ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Guarantor ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                  ],
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      List<dynamic> guarantors = List.from(localFormData[parentField.key] ?? []);
                      if (index < guarantors.length) {
                        guarantors.removeAt(index);
                        localFormData[parentField.key] = guarantors;
                        widget.onChanged(parentField.key, guarantors);
                      }
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Guarantor details
            if (guarantorName.isNotEmpty) ...[
              _buildGuarantorDetailRow('Name', guarantorName),
              const SizedBox(height: 8),
            ],
            _buildGuarantorDetailRow('Phone', guarantorPhone),
            if (amountToGuarantee.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildGuarantorDetailRow('Amount to Guarantee', 'Ksh. $amountToGuarantee'),
            ],
          ],
        ),
      );
    }

    // Default: show editable guarantor fields (for non-validated entries)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Guarantor ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              // IconButton(
              //   icon: Icon(Icons.delete, color: Colors.red, size: 20),
              //   onPressed: () {
              //     setState(() {
              //       List<dynamic> guarantors = List.from(localFormData[parentField.key] ?? []);
              //       guarantors.removeAt(index);
              //       localFormData[parentField.key] = guarantors;
              //     });
              //   },
              // ),
            ],
          ),
          const SizedBox(height: 12),

          // Build guarantor fields
          if (parentField.fieldArray != null) ...[
            for (var subField in parentField.fieldArray!) ...[
              if (subField.type.toLowerCase() == 'validateguarantor') ...[
                GuarantorField(
                  label: subField.templateOptions['label'] ?? 'Guarantor Phone',
                  isRequired: subField.isRequiredForFormData(localFormData),
                  initialValue: guarantor[subField.key]?.toString(),
                  formData: localFormData,
                  onChanged: (value) {
                    setState(() {
                      List<dynamic> guarantors = List.from(localFormData[parentField.key] ?? []);
                      if (index < guarantors.length) {
                        Map<String, dynamic> updatedGuarantor = Map<String, dynamic>.from(
                            guarantors[index] is Map<String, dynamic> ? guarantors[index] : {}
                        );
                        updatedGuarantor[subField.key] = value;
                        guarantors[index] = updatedGuarantor;
                        localFormData[parentField.key] = guarantors;
                      }
                    });
                  },
                  onValidated: (isValid, message) {
                    if (isValid && message == 'MORE_GUARANTORS_NEEDED') {
                      // Automatically add another guarantor
                      setState(() {
                        List<dynamic> guarantors = List.from(localFormData[parentField.key] ?? []);
                        guarantors.add({});
                        localFormData[parentField.key] = guarantors;
                      });
                    }
                  },
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  /// Validated guarantor display
  Widget _buildGuarantorDetailRow(String label, String value) {
    final isDark = widget.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Check if field is a contact picker field based on configuration
  bool _isContactPickerField(FormFieldModel field) {
    // Check for traditional contact picker attributes
    if (field.templateOptions.containsKey('attributes') &&
        field.templateOptions['attributes'] is Map &&
        field.templateOptions['attributes'].containsKey('ib_action') &&
        field.templateOptions['attributes']['ib_action'] ==
            'validateOtherAccount') {
      AppLogger.info(
          'Contact picker field detected: ${field.key} with ib_action');
      return true;
    }

    // Check if field has phone validation
    if (field.validators != null &&
        field.validators!.containsKey('validation')) {
      var validation = field.validators!['validation'];
      if (validation is List && validation.contains('phone')) {
        AppLogger.info(
            'Contact picker field detected: ${field.key} with phone validation');
        return true;
      }
    }

    // Check field label for phone-related keywords
    String label =
        (field.templateOptions['label'] ?? '').toString().toLowerCase();
    if (label.contains('phone') ||
        label.contains('mobile')) {
      AppLogger.info(
          'Contact picker field detected: ${field.key} with phone label');
      return true;
    }

    return false;
  }

  // Check if field is a phone field (for input validation)
  bool _isPhoneField(FormFieldModel field) {
    // Check field type
    String fieldType = field.templateOptions['type'] ?? field.type;
    if (fieldType == 'tel' || fieldType == 'phone') {
      return true;
    }

    // Check if field has phone validation
    if (field.validators != null &&
        field.validators!.containsKey('validation')) {
      var validation = field.validators!['validation'];
      if (validation is List && validation.contains('phone')) {
        return true;
      }
    }

    // Check field key for phone-related patterns
    String key = field.key.toLowerCase();
    if (key.contains('phone') ||
        key.contains('mobile') ||
        key.contains('msisdn') ||
        key.contains('tel')) {
      return true;
    }

    return false;
  }

  // Check if field has phone-related keywords in label or placeholder
  bool _hasPhoneKeywords(FormFieldModel field) {
    // Check field label for phone-related keywords
    String label =
        (field.templateOptions['label'] ?? '').toString().toLowerCase();
    if (label.contains('phone') ||
        label.contains('mobile') ||
        label.contains('tel')) {
      return true;
    }

    // Check placeholder for phone-related keywords
    String placeholder =
        (field.templateOptions['placeholder'] ?? '').toString().toLowerCase();
    if (placeholder.contains('phone') ||
        placeholder.contains('mobile') ||
        placeholder.contains('tel')) {
      return true;
    }

    return false;
  }

  Widget _buildPhoneField(FormFieldModel field) {
    final label = field.templateOptions['label'] ?? field.key;
    final isRequired = field.isRequiredForFormData(localFormData);
    final theme = Theme.of(context);
    final errorText = fieldErrors[field.key];

    // Create a controller if not exists
    if (!controllers.containsKey(field.key)) {
      controllers[field.key] = TextEditingController(
        text: localFormData[field.key]?.toString() ?? '',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 8),
        PhoneNumberField(
          controller: controllers[field.key]!,
          onChanged: (value) {
            setState(() {
              localFormData[field.key] = value;

              // Clear validation error if field is filled
              if (isRequired && value.isEmpty) {
                fieldErrors[field.key] = 'This field is required';
              } else {
                fieldErrors.remove(field.key);
              }
            });
            widget.onChanged(field.key, value);
          },
          onNumberSelected: (number) {
            AppLogger.info('Contact selected: $number for field ${field.key}');
            // Handle any additional logic when a contact is selected
          },
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileField(FormFieldModel field) {
    final label = field.templateOptions['label'] ?? field.key;
    final isRequired = field.isRequiredForFormData(localFormData);
    final theme = Theme.of(context);
    final errorText = fieldErrors[field.key];

    // Get current file
    File? currentFile = localFormData[field.key] as File?;

    final isDark = widget.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired, theme),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImageSourceDialog(field),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: currentFile != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          currentFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeFile(field),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add $label',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                          fontFamily: ClientThemeManager()
                              .currentClientConfig
                              .fontFamily,
                        ),
                      ),
                      if (field.templateOptions['accept'] != null)
                        Text(
                          'Accepted: ${field.templateOptions['accept']}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                            fontSize: 12,
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog(FormFieldModel field) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take Photo',
                style: TextStyle(
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(field, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(field, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(FormFieldModel field, ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      setState(() {
        localFormData[field.key] = File(image.path);

        // Clear validation error if field was previously invalid
        if (fieldErrors.containsKey(field.key)) {
          fieldErrors.remove(field.key);
        }
      });

      // Notify parent
      widget.onChanged(field.key, localFormData[field.key]);
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error selecting image: $e',
            style: TextStyle(
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  void _removeFile(FormFieldModel field) {
    setState(() {
      localFormData.remove(field.key);
    });

    widget.onChanged(field.key, null);
  }

  Widget _buildArrayField(FormFieldModel field) {
    final label = field.templateOptions['label'] ?? field.key;
    final isRequired = field.isRequiredForFormData(localFormData);
    final minItems = field.templateOptions['minItems'] ?? 1;
    final theme = Theme.of(context);
    final errorText = fieldErrors[field.key];

    // Get current array data
    List<dynamic> arrayData = localFormData[field.key] ?? [];

    // Check if this is guarantors field and currently validating
    final bool isValidatingThisField = field.key == 'guarantors' && _isValidatingGuarantor;

    // For guarantors, check if we need to initialize and check pending count
    bool isGuarantorsComplete = false;
    if (field.key == 'guarantors') {
      if (_guarantorPending == 0 && arrayData.isEmpty) {
        _initializeGuarantorPending();
      }

      isGuarantorsComplete = _guarantorPending <= 0 && arrayData.isNotEmpty;
    }

    final bool isAddButtonDisabled = isValidatingThisField || isGuarantorsComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel(label, isRequired, theme),
            TextButton.icon(
              icon: isValidatingThisField
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    )
                  : Icon(
                      isGuarantorsComplete ? Icons.check_circle : Icons.add,
                      color: isAddButtonDisabled ? Colors.grey : colors.primary,
                      size: 20,
                    ),
              label: Text(
                isValidatingThisField
                    ? 'Validating...'
                    : isGuarantorsComplete
                        ? 'All Added'
                        : field.templateOptions['addButtonLabel']?.toString() ??
                            'Add ${_singularize(label)}',
                style: TextStyle(
                  color: isAddButtonDisabled ? Colors.grey : colors.primary,
                  fontSize: 14,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              onPressed: isAddButtonDisabled
                  ? null
                  : () => _showArrayItemModal(field, null, null),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Show validation loader for guarantors
        if (field.key == 'guarantors' && _isValidatingGuarantor) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: colors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
              color: colors.primary.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Validating Guarantor...',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Display existing array items
        if (arrayData.isNotEmpty) ...[
          ...arrayData.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_singularize(label)} ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                          fontFamily: ClientThemeManager()
                              .currentClientConfig
                              .fontFamily,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hide edit button for validated guarantors when amountToGuarantee is not required
                          // Only show edit if: not a guarantor, OR not validated, OR amountToGuarantee field is required
                          if (field.key != 'guarantors' ||
                              item['isValidated'] != true ||
                              _requiresAmountToGuaranteeField())
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: colors.primary, size: 20),
                              onPressed: () =>
                                  _showArrayItemModal(field, item, index),
                            ),
                          IconButton(
                            icon:
                                Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _removeArrayItem(field, index),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Display item summary
                  ..._buildArrayItemSummary(item, field),
                ],
              ),
            );
          }).toList(),
        ] else if (!(field.key == 'guarantors' && _isValidatingGuarantor)) ...[
          // Hide "No items" when validating guarantors
          GestureDetector(
            // Make entire card displaying "No items added yet" clickable for adding an item
            onTap: field.key == 'nominees' || field.key == 'guarantors' ||
                field.key == 'documents'
                ? () => _showArrayItemModal(field, null, null)
                : null,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[50],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                        field.key == 'documents' ? Icons.description : Icons.people_outline,
                        color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400], size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No ${label.toLowerCase()} added yet. Click to add.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontFamily:
                            ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              errorText,
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildArrayItemSummary(
      Map<String, dynamic> item, FormFieldModel field) {
    List<Widget> summaryWidgets = [];

    // For guarantor array, phone, amount to guarantee, and status
    if (item['guarantorPhone'] != null) {
      String phone = item['guarantorPhone']?.toString() ?? '';
      String amount = item['amountToGuarantee']?.toString() ?? '';

      summaryWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              _buildGuarantorDetailRow(
                'Phone Number',
                _formatPhoneNumber(phone),
              ),
            // Only show amount if amountToGuarantee field is required
            if (amount.isNotEmpty && _requiresAmountToGuaranteeField())
              _buildGuarantorDetailRow(
                'Amount to Guarantee',
                'Ksh $amount',
              ),
            if (item['isValidated'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFamily:
                            ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          'Validated',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily:
                                ClientThemeManager().currentClientConfig.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    // For nominee array, show name and phone number
    else if (item['nom_fullName'] != null || item['nom_phoneNo'] != null) {
      String name = item['nom_fullName']?.toString() ?? 'No name';
      String phone = item['nom_phoneNo']?.toString() ?? 'No phone';
      String relationship =
          item['nom_relationship']?.toString() ?? 'Relationship not specified';

      summaryWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty)
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.textPrimary,
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _formatPhoneNumber(phone),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontFamily:
                        ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ),
            if (relationship.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Relationship: $relationship',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontFamily:
                        ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // Document/security summary
    else if (item['securityType'] != null) {
      String securityType = item['securityType']?.toString() ?? '';
      String securityValue = item['securityValue']?.toString() ?? '';

      summaryWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (securityType.isNotEmpty)
              _buildGuarantorDetailRow('Security Type', securityType),
            if (securityValue.isNotEmpty)
              _buildGuarantorDetailRow(
                'Security Value',
                'Ksh. ${NumberFormat('#,##0').format(double.tryParse(securityValue) ?? 0)}',
              ),
            if (item['securityImage'] != null && item['securityImage'] is File)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(item['securityImage'] as File),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      item['securityImage'] as File,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // Fallback to generic display if not a nominee array
    else {
      // Display key information from the item
      if (item['firstName'] != null || item['surname'] != null) {
        String name = '${item['firstName']?.toString() ?? ''} '
                '${item['middleName']?.toString() ?? ''} '
                '${item['surname']?.toString() ?? ''}'
            .trim();
        if (name.isNotEmpty) {
          summaryWidgets.add(_buildSummaryRow('Name:', name));
        }
      }

      if (item['phoneNumber'] != null) {
        summaryWidgets.add(
            _buildSummaryRow('Phone:', item['phoneNumber']?.toString() ?? ''));
      }

      if (item['idNumber'] != null) {
        summaryWidgets.add(
            _buildSummaryRow('ID Number:', item['idNumber']?.toString() ?? ''));
      }

      if (item['gender'] != null) {
        summaryWidgets
            .add(_buildSummaryRow('Gender:', item['gender']?.toString() ?? ''));
      }
    }

    return summaryWidgets;
  }

  String _formatPhoneNumber(String phone) {
    phone = phone.trim().replaceAll(RegExp(r'\s+'), '');

    if (phone.length == 9 && (phone.startsWith('7') || phone.startsWith('1'))) {
      phone = '254$phone';
    } else if (phone.length == 10 &&
        (phone.startsWith('07') || phone.startsWith('01'))) {
      phone = '254${phone.substring(1)}';
    }

    if (phone.length == 12 && phone.startsWith('254')) {
      return '+${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    }

    return phone;
  }

  /// Check if amountToGuarantee field is required based on FLD response
  /// Returns true if requiresAmountToGuaranteeField is "YES" or not specified (default behavior)
  bool _requiresAmountToGuaranteeField() {
    final fldResponse = widget.formData['fldResponse'];
    if (fldResponse == null) return true; // Default to showing field if no FLD response

    final requiresField = fldResponse['requiresAmountToGuaranteeField']?.toString().toUpperCase();
    AppLogger.info('requiresAmountToGuaranteeField from FLD: $requiresField');

    // Only hide if explicitly set to "NO"
    return requiresField != 'NO';
  }

  void _showFullScreenImage(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(imageFile),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 12,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showArrayItemModal(FormFieldModel field,
      Map<String, dynamic>? existingItem, int? editIndex) {
    // Check if no guarantors are required for the applied amount for this loan
    if (field.key == 'guarantors') {
      int guarantorsCount = widget.formData['guarantorsCount'] ??
                            localFormData['guarantorsCount'] ?? 0;
      AppLogger.info('_showArrayItemModal: guarantors required = $guarantorsCount');
      if (guarantorsCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No guarantors required for the applied amount'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Create local form data for the modal
    Map<String, dynamic> modalFormData =
        Map<String, dynamic>.from(existingItem ?? {});

    // Get array field structure from the original JSON in templateOptions
    List<FormFieldModel>? arrayFields = _getArrayFieldStructure(field);

    // Check if editing a validated guarantor - only allow editing amountToGuarantee
    final bool isEditingValidatedGuarantor = field.key == 'guarantors' &&
        existingItem != null &&
        existingItem['isValidated'] == true;

    // Check if amountToGuarantee field is required (for guarantors only)
    final bool requiresAmountField = _requiresAmountToGuaranteeField();
    final bool isGuarantorField = field.key == 'guarantors';

    // Filter fields for display
    List<FormFieldModel>? displayFields = arrayFields;
    if (arrayFields != null) {
      if (isEditingValidatedGuarantor) {
        // Editing validated guarantor - only show amountToGuarantee
        displayFields = arrayFields
            .where((f) => f.key == 'amountToGuarantee')
            .toList();
        AppLogger.info('Editing validated guarantor - only showing amountToGuarantee field');
      } else if (isGuarantorField && !requiresAmountField) {
        // Adding new guarantor but amountToGuarantee not required - hide the field
        displayFields = arrayFields
            .where((f) => f.key != 'amountToGuarantee')
            .toList();
        AppLogger.info('Adding guarantor - hiding amountToGuarantee field (not required)');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final isDark = widget.isDarkMode;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: isEditingValidatedGuarantor
                    ? MediaQuery.of(context).size.height * 0.4
                    : MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    // Modal header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditingValidatedGuarantor
                                ? 'Edit Amount to Guarantee'
                                : (existingItem != null
                                    ? 'Edit ${_singularize(field.templateOptions['label']?.toString() ?? 'Item')}'
                                    : 'Add ${_singularize(field.templateOptions['label']?.toString() ?? 'Item')}'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: ClientThemeManager()
                                  .currentClientConfig
                                  .fontFamily,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Modal content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: displayFields != null && displayFields.isNotEmpty
                            ? DynamicForm(
                                fields: displayFields,
                                onChanged: (key, value) {
                                  setModalState(() {
                                    modalFormData[key] = value;
                                  });
                                },
                                formData: modalFormData,
                                isDarkMode: isDark,
                              )
                            : Column(
                                children: [
                                  Icon(Icons.warning,
                                      color: Colors.orange, size: 60),
                                  SizedBox(height: 16),
                                  Text(
                                    'No fields defined for this array',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontFamily: ClientThemeManager()
                                          .currentClientConfig
                                          .fontFamily,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'The array field structure was not found in the service journey.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontFamily: ClientThemeManager()
                                          .currentClientConfig
                                          .fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // Modal actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextButton(
                              onPressed: displayFields != null &&
                                      displayFields.isNotEmpty
                                  ? () async {
                                      // Validated guarantors -> skip backend validation and just update amount
                                      if (isEditingValidatedGuarantor) {
                                        existingItem!['amountToGuarantee'] = modalFormData['amountToGuarantee'];
                                        _saveArrayItem(field, existingItem, editIndex);
                                        Navigator.pop(context);
                                        AppLogger.info('Updated validated guarantor amount to: ${modalFormData['amountToGuarantee']}');
                                        return;
                                      }

                                      // Use displayFields for validation (filtered list)
                                      // This ensures hidden fields like amountToGuarantee don't cause validation errors
                                      if (_validateArrayItem(
                                          modalFormData, displayFields!)) {
                                        // Validate guarantors
                                        if (field.key == 'guarantors') {
                                          Navigator.pop(context);

                                          // Determine the index for this guarantor
                                          int guarantorIndex = editIndex ??
                                              (localFormData[field.key] as List?)?.length ?? 0;

                                          // Validate in background
                                          _validateGuarantorInBackground(
                                              modalFormData, field, guarantorIndex);
                                        } else {
                                          // Non-guarantor arrays: existing behavior
                                          _saveArrayItem(
                                              field, modalFormData, editIndex);
                                          Navigator.pop(context);
                                        }
                                      }
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                backgroundColor: displayFields != null &&
                                        displayFields.isNotEmpty
                                    ? colors.primary
                                    : Colors.grey[400],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                existingItem != null ? 'Update' : 'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Validate guarantor in background after dialog is closed
  /// Shows loader during validation, only adds guarantor to list on success
  Future<void> _validateGuarantorInBackground(
    Map<String, dynamic> modalFormData,
    FormFieldModel field,
    int guarantorIndex,
  ) async {
    String guarantorPhone = modalFormData['guarantorPhone']?.toString() ?? '';
    String guarantorAmount = modalFormData['amountToGuarantee']?.toString() ?? '';
    String totalAmount = widget.formData['amt']?.toString() ?? '';

    // If amountToGuarantee field is not required, use total amount as the guarantor amount
    if (!_requiresAmountToGuaranteeField()) {
      guarantorAmount = totalAmount;
      AppLogger.info('amountToGuarantee not required - using total amount: $guarantorAmount');
    }

    if (guarantorPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number is required'),
          backgroundColor: colors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Set validating state to show loader (don't add to array yet)
    setState(() {
      _isValidatingGuarantor = true;
      _validatingGuarantorPhone = guarantorPhone;
    });

    try {
      final digitalLoansService = DigitalLoansService();

      // Build existing guarantors list for the payload
      List<dynamic> existingGuarantors = List.from(localFormData[field.key] ?? []);
      List<Map<String, String>> guarantorsPayload = existingGuarantors
          .where((g) => g is Map && g['guarantorPhone'] != null)
          .map<Map<String, String>>((g) => {
            'guarantorPhone': g['guarantorPhone']?.toString() ?? '',
            'guarantorAmount': g['amountToGuarantee']?.toString() ?? '',
          })
          .toList();

      // Add the new guarantor being validated
      guarantorsPayload.add({
        'guarantorPhone': guarantorPhone,
        'guarantorAmount': guarantorAmount,
      });

      // Guarantor validation data
      Map<String, dynamic> validationData = {
        'amt': totalAmount,
        'guarantors': guarantorsPayload,
        'guarantorPhone': guarantorPhone,
        'amountToGuarantee': guarantorAmount,
      };

      final result = await digitalLoansService.validateGuarantor(
        formData: validationData,
        eloanCode: widget.eloanCode ?? localFormData['eLoanCode']?.toString() ??
            localFormData['eloanCode']?.toString() ?? '',
      );

      String responseCode = result['responseCode']?.toString() ?? '';

      if (responseCode == '00' || responseCode == '02') {
        // Validation successful - use modal form data since backend doesn't return details
        // The phone and amount come from what the user entered in the modal
        String finalGuarantorPhone = guarantorPhone;
        String finalAmountToGuarantee = guarantorAmount;

        // Only add guarantor to array on successful validation
        setState(() {
          _isValidatingGuarantor = false;
          _validatingGuarantorPhone = '';

          List<dynamic> guarantors = List.from(localFormData[field.key] ?? []);
          guarantors.add({
            'guarantorPhone': finalGuarantorPhone,
            'amountToGuarantee': finalAmountToGuarantee,
            'isValidated': true,
            'validatedAt': DateTime.now().toIso8601String(),
          });
          localFormData[field.key] = guarantors;

          // Decrement guarantorPending in the display field
          _decrementGuarantorPending();
        });

        // Notify parent
        widget.onChanged(field.key, localFormData[field.key]);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guarantor validated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Validation failed - just reset the loader state (don't add to array)
        String errorMsg = result['narration']?.toString() ??
            result['message']?.toString() ??
            'Guarantor validation failed';

        setState(() {
          _isValidatingGuarantor = false;
          _validatingGuarantorPhone = '';
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: colors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Guarantor validation error: $e');

      // Reset loader state on error (don't add to array)
      setState(() {
        _isValidatingGuarantor = false;
        _validatingGuarantorPhone = '';
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to validate guarantor. Please try again.'),
          backgroundColor: colors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<FormFieldModel>? _getArrayFieldStructure(FormFieldModel field) {
    if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
      return field.fieldArray!;
    }

    if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
      return field.fieldGroup!;
    }

    return null;
  }

  bool _validateArrayItem(
      Map<String, dynamic> itemData, List<FormFieldModel> arrayFields) {
    for (var itemField in arrayFields) {
      bool isRequired = itemField.isRequiredForFormData(itemData);

      if (isRequired) {
        // Handle hideExpression for conditional fields using the enhanced evaluator
        if (itemField.hideExpression != null) {
          if (_evaluateHideExpression(itemField.hideExpression!, itemData)) {
            continue; // Skip validation for hidden fields
          }
        }

        bool isEmpty = !itemData.containsKey(itemField.key) ||
            itemData[itemField.key] == null ||
            (itemField.type != 'file' &&
                itemData[itemField.key].toString().isEmpty);

        // For file fields, check if it's actually a file
        if (itemField.type == 'file' && itemData[itemField.key] != null) {
          isEmpty = !(itemData[itemField.key] is File);
        }

        if (isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${itemField.templateOptions['label']} is required',
                style: TextStyle(
                  fontFamily:
                      ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              backgroundColor: colors.error,
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  void _saveArrayItem(
      FormFieldModel field, Map<String, dynamic> itemData, int? editIndex) {
    setState(() {
      List<dynamic> arrayData =
          List<dynamic>.from(localFormData[field.key] ?? []);

      if (editIndex != null) {
        arrayData[editIndex] = itemData;
      } else {
        arrayData.add(itemData);
      }

      localFormData[field.key] = arrayData;

      if (fieldErrors.containsKey(field.key)) {
        fieldErrors.remove(field.key);
      }
    });

    widget.onChanged(field.key, localFormData[field.key]);
  }

  void _removeArrayItem(FormFieldModel field, int index) {
    List<dynamic> arrayData = localFormData[field.key] ?? [];
    Map<String, dynamic>? item = index < arrayData.length ? arrayData[index] : null;

    String dialogTitle;
    String dialogMessage;
    String itemIdentifier = '';

    if (field.key == 'guarantors') {
      dialogTitle = 'Remove Guarantor';
      String phone = item?['guarantorPhone']?.toString() ?? '';
      if (phone.isNotEmpty) {
        itemIdentifier = _formatPhoneNumber(phone);
      }
      dialogMessage = itemIdentifier.isNotEmpty
          ? 'Are you sure you want to remove the guarantor ($itemIdentifier)?'
          : 'Are you sure you want to remove this guarantor?';
    } else if (field.key == 'documents') {
      dialogTitle = 'Remove Document';
      String securityType = item?['securityType']?.toString() ?? '';
      if (securityType.isNotEmpty) {
        itemIdentifier = securityType;
      }
      dialogMessage = itemIdentifier.isNotEmpty
          ? 'Are you sure you want to remove this document ($itemIdentifier)?'
          : 'Are you sure you want to remove this document?';
    } else if (field.key == 'nominees' || field.key.toLowerCase().contains('nominee')) {
      dialogTitle = 'Remove Nominee';
      String name = item?['nom_fullName']?.toString() ?? item?['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        itemIdentifier = name;
      }
      dialogMessage = itemIdentifier.isNotEmpty
          ? 'Are you sure you want to remove $itemIdentifier as a nominee?'
          : 'Are you sure you want to remove this nominee?';
    } else {
      String label = _singularize(field.templateOptions['label']?.toString() ?? 'Item');
      dialogTitle = 'Remove $label';
      dialogMessage = 'Are you sure you want to remove this ${label.toLowerCase()}?';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          dialogTitle,
          style: TextStyle(
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
        content: Text(
          dialogMessage,
          style: TextStyle(
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                List<dynamic> currentArrayData =
                    List<dynamic>.from(localFormData[field.key] ?? []);
                currentArrayData.removeAt(index);
                localFormData[field.key] = currentArrayData;

                // Increment guarantorPending when a guarantor is removed
                if (field.key == 'guarantors') {
                  _incrementGuarantorPending();
                }
              });

              widget.onChanged(field.key, localFormData[field.key]);
              Navigator.pop(context);
            },
            child: Text(
              'Remove',
              style: TextStyle(
                color: Colors.red,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _evaluateHideExpression(
      String expression, Map<String, dynamic> formData) {
    try {
      print("=== EVALUATING HIDE EXPRESSION ===");
      print("Expression: $expression");
      print("Form data: $formData");

      // Replace model.fieldName with actual values
      String evaluatedExpression = expression;

      // Find all model.fieldName patterns and replace with actual values
      RegExp regex = RegExp(r'model\.(\w+)');
      evaluatedExpression =
          evaluatedExpression.replaceAllMapped(regex, (match) {
        String fieldName = match.group(1)!;
        dynamic value = formData[fieldName];

        print("Field reference: $fieldName = $value");

        // Handle null/undefined values - CRITICAL for initial state
        if (value == null || value.toString().isEmpty) {
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

      print("After replacement: $evaluatedExpression");

      // Handle logical operators (|| and &&)
      if (evaluatedExpression.contains('||') ||
          evaluatedExpression.contains('&&')) {
        return _evaluateComplexExpression(evaluatedExpression, formData);
      }

      // Handle != operator
      if (evaluatedExpression.contains('!=')) {
        List<String> parts =
            evaluatedExpression.split('!=').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");

          // CRITICAL: Handle null comparison properly
          bool result;
          if (left == 'null') {
            result = right != 'null'; // null != 'IAT' is true
          } else {
            result = left != right;
          }

          print("!= comparison: '$left' != '$right' = $result");
          return result;
        }
      }

      // Handle == operator
      if (evaluatedExpression.contains('==')) {
        evaluatedExpression = evaluatedExpression.replaceAll('===', '==');
        List<String> parts =
            evaluatedExpression.split('==').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");

          // CRITICAL: Handle null comparison properly
          bool result;
          if (left == 'null') {
            result = right == 'null'; // null == 'IAT' is false
          } else {
            result = left == right;
          }

          print("== comparison: '$left' == '$right' = $result");
          return result;
        }
      }

      // Handle negation expressions like !model.fieldName
      if (evaluatedExpression.startsWith('!')) {
        String value = evaluatedExpression.substring(1).trim();
        if (value == 'null') {
          return true; // !null is true
        } else if (value.isEmpty || value == "''") {
          return true; // !empty is true
        } else {
          return false; // !non-empty is false
        }
      }

      print("Unhandled expression, defaulting to false");
      return false;
    } catch (e) {
      print('Error evaluating hideExpression: $expression, Error: $e');
      return false;
    }
  }

  // Evaluate complex expressions with logical operators
  bool _evaluateComplexExpression(
      String expression, Map<String, dynamic> formData) {
    // Remove any unnecessary whitespace
    expression = expression.replaceAll(' ', '');

    // Handle precedence: && has higher precedence than ||
    List<String> andParts = _splitByOperator(expression, '&&');
    if (andParts.length > 1) {
      bool result = true;
      for (String part in andParts) {
        result = result && _evaluateComplexExpression(part, formData);
      }
      return result;
    }

    // If no &&, check for ||
    List<String> orParts = _splitByOperator(expression, '||');
    if (orParts.length > 1) {
      bool result = false;
      for (String part in orParts) {
        result = result || _evaluateComplexExpression(part, formData);
      }
      return result;
    }

    // Base case: evaluate simple expression
    return _evaluateSimpleExpression(expression, formData);
  }

  // Split expression by operator, respecting parentheses
  List<String> _splitByOperator(String expression, String operator) {
    List<String> parts = [];
    int parenCount = 0;
    String currentPart = '';
    int operatorIndex = -1;

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];
      if (char == '(') parenCount++;
      if (char == ')') parenCount--;

      if (parenCount == 0 && expression.startsWith(operator, i)) {
        operatorIndex = i;
        break;
      }
      currentPart += char;
    }

    if (operatorIndex != -1) {
      parts.add(expression.substring(0, operatorIndex));
      parts.add(expression.substring(operatorIndex + operator.length));
    } else {
      parts.add(expression);
    }

    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  // Evaluate a simple expression (e.g., left == right or left != right)
  bool _evaluateSimpleExpression(
      String expression, Map<String, dynamic> formData) {
    if (expression.contains('!=')) {
      List<String> parts = expression.split('!=').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        String left = parts[0].replaceAll("'", "");
        String right = parts[1].replaceAll("'", "");
        return left != right;
      }
    } else if (expression.contains('==')) {
      List<String> parts = expression.split('==').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        String left = parts[0].replaceAll("'", "");
        String right = parts[1].replaceAll("'", "");
        return left == right;
      }
    } else if (expression.startsWith('!')) {
      String value = expression.substring(1).trim();
      return value == 'null' || value == "''";
    }
    return false;
  }

  /// Decrement the guarantorPending count and update the displayField
  void _decrementGuarantorPending() {
    if (_guarantorPending > 0) {
      _guarantorPending--;

      // Update the displayField's templateOptions to reflect the new pending count
      _updateGuarantorPendingInDisplayField();
    }
  }

  void _incrementGuarantorPending() {
    _guarantorPending++;

    // Update the displayField's templateOptions to reflect the new pending count
    _updateGuarantorPendingInDisplayField();
  }

  /// Update the guarantorPending value in the displayField's templateOptions
  void _updateGuarantorPendingInDisplayField() {
    // Find the displayField in the form fields and update its templateOptions
    for (var field in widget.fields) {
      if (field.type == 'display' && field.responseType == 'DIGITALLOANS') {
        final templateOptions = field.templateOptions;
        if (templateOptions.containsKey('guarantorPending')) {
          // Update the guarantorPending value
          String currentValue = templateOptions['guarantorPending']?.toString() ?? '';
          // Format: "Guarantor(s) Pending: X"
          final colonIndex = currentValue.indexOf(':');
          if (colonIndex > 0) {
            String label = currentValue.substring(0, colonIndex + 1);
            templateOptions['guarantorPending'] = '$label $_guarantorPending';
          }
        }
        break;
      }

      // Also check in fieldGroup for nested fields
      if (field.fieldGroup != null) {
        for (var subField in field.fieldGroup!) {
          if (subField.type == 'display' && subField.responseType == 'DIGITALLOANS') {
            final templateOptions = subField.templateOptions;
            if (templateOptions.containsKey('guarantorPending')) {
              String currentValue = templateOptions['guarantorPending']?.toString() ?? '';
              final colonIndex = currentValue.indexOf(':');
              if (colonIndex > 0) {
                String label = currentValue.substring(0, colonIndex + 1);
                templateOptions['guarantorPending'] = '$label $_guarantorPending';
              }
            }
            break;
          }
        }
      }
    }
  }

  /// Initialize guarantorPending from the displayField
  void _initializeGuarantorPending() {
    for (var field in widget.fields) {
      _extractGuarantorPendingFromField(field);
      if (_guarantorPending > 0) return;

      // Check in fieldGroup for nested fields
      if (field.fieldGroup != null) {
        for (var subField in field.fieldGroup!) {
          _extractGuarantorPendingFromField(subField);
          if (_guarantorPending > 0) return;
        }
      }
    }
  }

  /// Extract guarantorPending value from a field's templateOptions
  void _extractGuarantorPendingFromField(FormFieldModel field) {
    if (field.type == 'display' && field.responseType == 'DIGITALLOANS') {
      final templateOptions = field.templateOptions;
      if (templateOptions.containsKey('guarantorPending')) {
        String value = templateOptions['guarantorPending']?.toString() ?? '';
        // Format: "Guarantor(s) Pending: X"
        final colonIndex = value.indexOf(':');
        if (colonIndex > 0) {
          String numStr = value.substring(colonIndex + 1).trim();
          _guarantorPending = int.tryParse(numStr) ?? 0;
        }
      }
    }
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
