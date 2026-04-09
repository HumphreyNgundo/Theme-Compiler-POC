import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../configuration/client_config.dart';
import '../models/form_field_model.dart';
import '../models/form_journey_model.dart';
import '../models/message_template_model.dart';
import '../services/customer_validation_service.dart';
import '../services/digital_loans_service.dart';
import '../services/service_charge_service.dart';
import '../utils/color_palette.dart';
import '../services/account_filtering_service.dart';
import '../services/account_manager.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../services/cryptographer.dart';
import '../services/shared_preferences_helper.dart';
import '../widgets/dynamic_form.dart';
import '../widgets/generic_confirmation_dialog.dart';
import 'dashboard_screen.dart';
import 'pending_loans_screen.dart';
import 'transaction_receipt_screen.dart';
import '../services/transaction_service.dart';
import '../auth/otp_verification_screen.dart';
import '../auth/login_screen.dart';
import '../widgets/unified_otp_dialog.dart';
import '../services/auth_service.dart';
import '../services/token_refresh_service.dart';
import '../widgets/modern_dialogs.dart';
import '../widgets/service_charge_widget.dart';
import '../utils/app_logger.dart';
import '../utils/idle_timer.dart';
import '../services/session_expiry_handler.dart';

class FormJourneyScreen extends StatefulWidget {
  final String serviceCode;
  final String? balanceEnquiryType;
  final List<dynamic>? accounts;
  final Map<String, dynamic>? tileResponse;
  final bool lockAccountSelection;
  final dynamic preSelectedAccount;
  final String? accountType;
  final String? transactionType;
  final String? eloanCode;
  final Map<String, dynamic>? extraParams;
  final String? loanTitle;

  const FormJourneyScreen({
    super.key,
    required this.serviceCode,
    this.balanceEnquiryType,
    this.accounts,
    this.tileResponse,
    this.lockAccountSelection = false,
    this.preSelectedAccount,
    this.accountType,
    this.transactionType,
    this.eloanCode,
    this.extraParams,
    this.loanTitle,
  });

  get serviceName => null;

  @override
  FormJourneyScreenState createState() => FormJourneyScreenState();
}

class FormJourneyScreenState extends State<FormJourneyScreen> with TickerProviderStateMixin {
  bool isLoading = true;
  List<FormJourneyModel> journeys = [];
  Map<String, dynamic> formData = {};
  bool isProcessing = false;
  String? errorMessage;
  bool _isNoEligibleAccountsError = false;
  final AuthService _authService = AuthService();
  bool _hasEmailValidationErrors = false;
  bool _hasFormValidationErrors = false;
  bool _isInPinRetryMode = false;
  Map<String, dynamic>? serviceConfig;
  List<Map<String, dynamic>> allAccounts = [];
  List<Map<String, dynamic>> _loanAccounts = [];
  bool _loadingLoans = false;
  String? _loanError;
  Map<String, List<Map<String, dynamic>>> fieldAccountOptions = {};
  MessageTemplateConfig? messageTemplateConfig;
  int _expandedIndex = -1;
  final TextEditingController _phoneController = TextEditingController();
  final CustomerValidationService _customerValidationService = CustomerValidationService();
  final DigitalLoansService _digitalLoansService = DigitalLoansService();
  bool _isValidatingPhone = false;
  String ? _validatedCustomerName;
  String? _phoneValidationMessage;
  FocusNode _phoneFocusNode = FocusNode();
  FocusNode _amountFocusNode = FocusNode();
  bool _navigated = false;

  /// Field keys to lock in DynamicForm (e.g., txnType radio for carousel deposits)
  Set<String> _lockedFieldKeys = {};
  bool _infoBlinking = false;

  // Step navigation state variables
  int _currentStepIndex = 0;
  Map<int, Map<String, dynamic>> _stepFormData = {}; // Preserve data per step
  bool _isCheckingEligibility = false; // For button-driven eligibility
  String? _eligibilityError; // Store eligibility error
  String? _lastCheckedAmount; // Track last checked loan amount
  String? _lastCheckedPeriod; // Track last checked repayment period

  // Tab navigation state for tabbed journeys (ASL)
  TabController? _tabController;
  List<FormFieldModel> _visibleTabs = [];

  // Store original displayField templateOptions from service journey for re-substitution
  Map<String, String> _originalDisplayFieldTemplates = {};
  // Store guarantor display field labels separately (extracted from journey config)
  Map<String, String> _guarantorDisplayFieldTemplates = {};

  static const Set<String> enquiryServiceCodes = {
    'SCBE',
    'SBE',
    'NWDB',
    'LB',
    'ASB',
    'ASCB',
    'ALB',
    'ANB', // All Balances
    'MS',
    'AS',
  };

  static const Set<String> b2bServiceCodes = {
    'TTB', 'PTT', 'MFL', // Transfer to Bank, Pay to Till, Purchase Mpesa Float
  };

  @override
  void initState() {
    super.initState();
    _checkAccountLockStatus();
    TokenRefreshService.instance.recordUserInteraction();
    _phoneFocusNode.addListener(_onPhoneFocusChange);

    // Store account styling info if pre-selected (for locked account cards)
    if (widget.preSelectedAccount != null) {
      String accountType = widget.accountType ?? _determineAccountType(
          widget.preSelectedAccount['accountName'] ?? ''
      );
    }
    _initializeData();
  }

  void _onPhoneFocusChange() {
    // Trigger validation when phone field loses focus
    if (!_phoneFocusNode.hasFocus) {
      _validatePhoneNumberOnBlur();
    }
  }

  Future<void> _validatePhoneNumberOnBlur() async {
    final serviceCode = widget.serviceCode;
    final txnType = formData['txnType']?.toString();
    // Check if transaction requires phone number validation (WDO or Buy Airtime)
    bool isWithdrawal = (serviceCode == 'WD' || serviceCode == 'WDO') && txnType == 'WDO';
    bool isBuyAirtime = (serviceCode == 'AT') && txnType == 'ATO';

    if (!isWithdrawal && !isBuyAirtime) {
      return;
    }

    final phoneNumber = formData['description']?.toString();

    // Validate phone number format first
    if (phoneNumber == null || phoneNumber.isEmpty) {
      setState(() {
        _phoneValidationMessage = null;
        _validatedCustomerName = null;
        formData.remove('recipientName');
        formData.remove('recipientPhoneNumber');
      });
      return;
    }
    formData['recipientPhoneNumber'] = phoneNumber;

    if (!_isValidPhoneNumber(phoneNumber)) {
      setState(() {
        _phoneValidationMessage = 'Please enter a valid phone number';
        _validatedCustomerName = null;
        formData.remove('recipientName');
      });
      return;
    }

    setState(() {
      _isValidatingPhone = true;
      _phoneValidationMessage = null;
      _validatedCustomerName = null;
    });

    try {
      // Both WDO and Buy Airtime use WDO for validation API
      const validationServiceCode = 'WDO';
      final customerName = await _customerValidationService.validateCustomer(
        msisdn: phoneNumber,
        context: context,
        serviceCode: validationServiceCode,
      );

      if (customerName != null && CustomerValidationService.isValidCustomerName(customerName)) {
        setState(() {
          final formattedName = CustomerValidationService.formatCustomerName(customerName);
          _validatedCustomerName = customerName;
          _phoneValidationMessage = 'Recipient: $formattedName';
          formData['recipientName'] = formattedName;
        });
      } else {
        // Name not found - fallback to phone number for recipientName
        setState(() {
          _phoneValidationMessage = null;
          _validatedCustomerName = null;
          formData['recipientName'] = phoneNumber;
        });
      }
    } catch (e) {
      AppLogger.error('Phone validation error: $e');
      // Validation failed - fallback to phone number for recipientName
      setState(() {
        _phoneValidationMessage = 'Failed to validate recipient';
        _validatedCustomerName = null;
        formData['recipientName'] = phoneNumber;
      });
    } finally {
      setState(() {
        _isValidatingPhone = false;
      });
    }
  }

  bool _isValidPhoneNumber(String phone) {
    // Remove any non-digit characters
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedPhone.length < 10 || cleanedPhone.length > 12) {
      return false;
    }
    if (!(cleanedPhone.startsWith('254') || cleanedPhone.startsWith('01')  ||
        cleanedPhone.startsWith('07'))) {
      return false;
    }

    return true;
  }

  /// Populate description field and related data when user selects "withdrawal to my number"
  void _populateMyNumberWithdrawal() async {
    try {
      // Get user's phone number from SharedPreferencesHelper
      final userPhone = await SharedPreferencesHelper.getMsisdn();

      if (userPhone == null || userPhone.isEmpty) {
        AppLogger.warning('User phone number not found in SharedPreferences');
        return;
      }

      // Set the user's phone in formData for withdrawal to my number
      formData['description'] = userPhone;
      formData['recipientPhoneNumber'] = userPhone;
      formData['recipientName'] = 'My Number';
      _validatedCustomerName = 'My Number';
      _phoneValidationMessage = 'Recipient: My Number';

      AppLogger.info('Auto-populated withdrawal to my number with phone: $userPhone');
    } catch (e) {
      AppLogger.error('Error setting up withdrawal to my number: $e');
    }
  }

  /// Clear description field and related data when user switches to "withdrawal to other"
  void _clearMyNumberWithdrawalData() {
    formData['description'] = '';
    formData.remove('recipientPhoneNumber');
    formData.remove('recipientName');
    _validatedCustomerName = null;
    _phoneValidationMessage = null;

    AppLogger.info('Cleared my number withdrawal data');
  }

  /// Check if account is currently locked and logout if necessary
  void _checkAccountLockStatus() async {
    String? phoneNumber = await SharedPreferencesHelper.getMsisdn();

    if (phoneNumber != null) {
      AuthResult lockStatus =
      await _authService.checkTransactionLockStatus(phoneNumber);
      if (lockStatus.type == AuthResultType.accountLocked) {
        // Account is locked - show message and logout immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ModernDialogs.showError(
            context: context,
            title: 'Account Locked',
            message: lockStatus.message,
            onPressed: () {
              Navigator.pop(context); // Close the error dialog
              _logoutAndNavigateToLogin(); // Logout and go to login screen
            },
          );
        });
      }
    }
  }

  void _initializeData() async {
    if (widget.accounts != null) {
      allAccounts = widget.accounts!.map((account) {
        if (account is Map) {
          Map<String, dynamic> processedAccount =
          Map<String, dynamic>.from(account);
          // Ensure account type flags are set for filtering
          _setAccountTypeFlags(processedAccount);
          return processedAccount;
        }
        return <String, dynamic>{};
      }).toList();
    }

    _fetchServiceJourney();
  }

  Future<void> _fetchServiceJourney() async {
    // DL -> has no service journey, show loan accounts directly
    if (widget.serviceCode == 'DL') {
      AppLogger.info('DL service detected - loading loan accounts directly');
      await _loadLoanAccounts();
      return;
    }

    // PL -> has no service journey, navigate to pending loans screen
    if (widget.serviceCode == 'PL' && !_navigated) {
      _navigated = true;
      AppLogger.info('PL service detected - navigating to pending loans screen');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PendingLoansScreen(
            title: widget.loanTitle,
            serviceCode: 'IDL',
            eloanCode: widget.eloanCode,
            accounts: widget.accounts,
            tileResponse: widget.tileResponse,
          )),
        );
      });

      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      _isNoEligibleAccountsError = false;
    });

    try {
      final api = ApiService();
      final clientId = await SharedPreferencesHelper.getClientId();
      final phone = await SharedPreferencesHelper.getMsisdn();
      final storedKey = await SharedPreferencesHelper.getSecretKey();
      final imei = await api.getDeviceId();

      if (phone == null) throw Exception('Phone number not found');
      if (storedKey == null) throw Exception('Secret key not found');

      final aes = AesEncryption();
      final encryptedPhone = aes.encryptWithBase64Key(phone, storedKey);

      // eloanCode for Digital Loans (IDL)
      String? eloanCodeFromWidget = (widget.eloanCode != null && widget.eloanCode!.isNotEmpty)
          ? widget.eloanCode
          : null;

      String? eloanCode = eloanCodeFromWidget;
      String? encryptedEloanCode;

      if (eloanCode != null && eloanCode.isNotEmpty) {
        encryptedEloanCode = aes.encryptWithBase64Key(eloanCode, storedKey);
      } else {
        AppLogger.info(
            'Form_journey_screen: No eloanCode found for serviceCode=${widget.serviceCode} from the widget');
      }

      final requestBody = {
        'categoryName': 'Spotcash_App',
        'clientId': clientId,
        'serviceCode': widget.serviceCode,
        'phoneNumber': encryptedPhone,
        'imei': imei,
      };

      if (encryptedEloanCode != null) {
        requestBody['eloanCode'] = encryptedEloanCode;
      }

      final rawResponse = await api.postRequest(
        ApiEndpoints.getServiceJourney,
        requestBody,
      );

      AppLogger.info('rawResponse keys=${rawResponse.keys.toList()}');

      Map<String, dynamic> payload;

      if (rawResponse.containsKey('hashedBody')) {
        String decryptionKey = storedKey;

        if (rawResponse['znak'] != null &&
            rawResponse['znak'].toString().isNotEmpty) {
          try {
            final token = rawResponse['znak'].toString();
            final tokenPayload = JwtDecoder.decode(token);
            if (tokenPayload['tajemnica'] != null) {
              decryptionKey = tokenPayload['tajemnica'];
              await SharedPreferencesHelper.setToken(token);
              await SharedPreferencesHelper.setSecretKey(decryptionKey);
              AppLogger.info('updated tajemnica from token');
            }
          } catch (e) {
            AppLogger.error('token decode: $e');
          }
        }

        final decrypted = aes.decryptWithBase64Key(
          rawResponse['hashedBody'],
          decryptionKey,
        );
        payload = jsonDecode(decrypted) as Map<String, dynamic>;
        // Log full payload without truncation
        // final payloadStr = payload.toString();
        // debugPrint('Decrypted serviceConfigs start >>>');
        // for (int i = 0; i < payloadStr.length; i += 800) {
        //   debugPrint(payloadStr.substring(i, i + 800 > payloadStr.length ? payloadStr.length : i + 800));
        // }
        // debugPrint('<<< Decrypted serviceConfigs end');
      } else {
        payload = Map<String, dynamic>.from(rawResponse);
      }

      if (payload['responseCode'] == '00' && payload['entity'] != null) {
        final entity = Map<String, dynamic>.from(payload['entity']);

        serviceConfig = entity;
        AppLogger.info('serviceConfig loaded: code=${serviceConfig?['serviceCode']} name=${serviceConfig?['serviceName']}');
        final serviceJourneyString = entity['serviceJourney'];
        if (serviceJourneyString == null ||
            (serviceJourneyString is String && serviceJourneyString.isEmpty)) {
          throw Exception('Service journey is empty');
        }

        final serviceJourneyJson = serviceJourneyString is String
            ? jsonDecode(serviceJourneyString)
            : serviceJourneyString;

        journeys = (serviceJourneyJson as List)
            .map((j) => FormJourneyModel.fromJson(
          LinkedHashMap<String, dynamic>.from(j as Map),
        ))
            .toList();

        if (journeys.isEmpty) {
          throw Exception('No form journey data found');
        }

        // Ensure formData exists before building the template
        _initializeFormData();

        // Store original displayField templates for IDL before any substitution
        if (widget.serviceCode == 'IDL') {
          _storeOriginalDisplayFieldTemplates();
        }

        // Store eloanCode and productName in formData for any tile that has eloanCode
        if (widget.eloanCode != null && widget.eloanCode!.isNotEmpty) {
          formData['eloanCode'] = widget.eloanCode;
          AppLogger.info('Stored eloanCode for ${widget.serviceCode}: ${widget.eloanCode}');

          if (widget.loanTitle != null && widget.loanTitle!.isNotEmpty) {
            // Title case: capitalize first letter of each word
            String formattedTitle = widget.loanTitle!
                .split(' ')
                .map((word) => word.isNotEmpty
                    ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                    : '')
                .join(' ');
            formData['productName'] = formattedTitle;
            formData['eloanName'] = formattedTitle;
            AppLogger.info('Stored productName/eloanName for ${widget.serviceCode}: $formattedTitle');
          }
        }

        // ASL (Secured Loans) -> inject loanProduct data and initialize tabs
        if (widget.serviceCode == 'ASL') {
          final loanProduct = widget.tileResponse?['loanProduct'] as Map<String, dynamic>?;
          if (loanProduct != null) {
            formData['loanProduct'] = loanProduct;
            formData['productCode'] = loanProduct['productCode'];
            formData['productName'] = loanProduct['productName'];

            // Parse requiredSecurities (comma-separated: "guarantors,securities,documents")
            // into individual boolean flags for hideExpression evaluation
            final requiredSecurities = loanProduct['requiredSecurities']?.toString() ?? '';
            final securitiesList = requiredSecurities.split(',').map((s) => s.trim().toLowerCase()).toList();
            formData['requiredSecurities'] = requiredSecurities;
            formData['requiredSecurities_guarantors'] = securitiesList.any((s) => s.startsWith('guarant'));
            formData['requiredSecurities_securities'] = securitiesList.any((s) => s.startsWith('securit'));
            formData['requiredSecurities_documents'] = securitiesList.any((s) => s.startsWith('document'));

            AppLogger.info('ASL loanProduct: ${loanProduct['productName']}, '
                'requiredSecurities: $requiredSecurities, '
                'guarantors=${formData['requiredSecurities_guarantors']}, '
                'securities=${formData['requiredSecurities_securities']}, '
                'documents=${formData['requiredSecurities_documents']}');
          }

          if (widget.loanTitle != null && widget.loanTitle!.isNotEmpty) {
            formData['productName'] = widget.loanTitle;
          }

          // Initialize tab controller for tabbed journeys
          _initializeTabController();
        }

        // Prefill form with loan account details if preSelectedAccount is provided
        _prefillWithPreSelectedAccount();

        _parseMessageTemplates();

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final msg = (payload['message'] ??
          payload['responseMessage'] ??
          'Failed to load service')
          .toString();
      AppLogger.error('service config error: $msg');

      // Detect account-related errors (backend filtering returned no eligible accounts)
      final msgLower = msg.toLowerCase();
      final isAccountError = msgLower.contains('account') &&
          (msgLower.contains('not') || msgLower.contains('no ') ||
           msgLower.contains('could not') || msgLower.contains('unavailable') ||
           msgLower.contains('try') || msgLower.contains('later'));

      if (mounted) {
        setState(() {
          isLoading = false;
          _isNoEligibleAccountsError = isAccountError;
          errorMessage = isAccountError
              ? 'We couldn\'t find a valid account for this transaction. '
              'Please contact your SACCO for assistance.'
              : msg;
        });
      }
      // if (!isAccountError) {
      //   _showErrorSnackBar(msg);
      // }
    } catch (e) {
      AppLogger.error('fetch service journey: $e');

      final es = e.toString();
      if (es.contains('HTTP 401') || es.contains('HTTP 403')) {
        // Handle 401/403 gracefully with token refresh attempt
        if (mounted) {
          final recovered = await SessionExpiryHandler().handle401Error(
            context: context,
            showDialog: false,
          );

          if (recovered) {
            // Token was refreshed successfully, retry the request
            AppLogger.info('Retrying service journey fetch after token refresh');
            await _fetchServiceJourney();
            return;
          }
        }
        // If recovery failed, logout was already handled by SessionExpiryHandler
        return;
      }

      if (es.contains('Session expired')) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load service configuration';
        });
      }
      // _showErrorSnackBar('Failed to load service configuration');
    }
  }

  void _parseMessageTemplates() {
    AppLogger.info('=== PARSING MESSAGE TEMPLATES ===');

    if (serviceConfig == null) {
      AppLogger.error('serviceConfig is null, cannot parse templates');
      return;
    }

    try {
      messageTemplateConfig = MessageTemplateConfig.fromServiceConfig(serviceConfig!);

      // Log each field in the success template
      AppLogger.info('Success template fields count: ${messageTemplateConfig?.successTemplate?.fields.length}');
      if (messageTemplateConfig?.successTemplate != null) {
        for (var field in messageTemplateConfig!.successTemplate!.fields) {
          AppLogger.info('Success template field: ${field.label} -> ${field.value}');
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error parsing message templates: $e');
      messageTemplateConfig = null;
    }
  }

  /// Load loan accounts from cached accounts
  Future<void> _loadLoanAccounts() async {
    try {
      setState(() {
        _loadingLoans = true;
        _loanError = null;
      });

      final cachedAccounts = await AccountManager.getCachedAccounts();
      if (cachedAccounts == null || cachedAccounts.isEmpty) {
        setState(() {
          _loanError = 'No accounts found. Please refresh your accounts.';
          _loadingLoans = false;
        });
        return;
      }

      final loanAccounts = _filterLoanAccounts(cachedAccounts);
      if (loanAccounts.isEmpty) {
        setState(() {
          _loanError = 'You do not have any ${widget.loanTitle?.toLowerCase() ?? 'active loans'}';
          _loadingLoans = false;
        });
        return;
      }

      setState(() {
        _loanAccounts = loanAccounts;
        _loadingLoans = false;
      });
    } catch (e) {
      AppLogger.error('loading loan accounts: $e');
      setState(() {
        _loanError = 'Sorry! Your ${widget.loanTitle?.toLowerCase() ?? 'active loans'} could not be loaded. Please try again later.';
        _loadingLoans = false;
      });
    }
  }

  /// Filter loan accounts from all accounts
  List<Map<String, dynamic>> _filterLoanAccounts(List<dynamic> accounts) {
    bool isLoanAccount(dynamic value) {
      if (value == null) return false;

      if (value is num) {
        return value == 1;
      }

      if (value is bool) {
        return value;
      }

      final normalized = value.toString().trim().toLowerCase();

      return normalized == 'yes' || normalized == 'true' || normalized == '1';
    }

    return accounts
        .where((account) => account != null)
        .map((account) => account is Map<String, dynamic>
        ? account
        : Map<String, dynamic>.from(account))
        .where((account) =>
    isLoanAccount(account['isLoanAccount']) ||
        (account['accountName']?.toString().toLowerCase().contains('loan') ?? false) ||
        (account['accountType']?.toString().toLowerCase().contains('loan') ?? false))
        .toList();
  }

  /// Determine account type from account name
  String _determineAccountType(String accountName) {
    final name = accountName.toUpperCase();
    if (name.contains('SAVINGS') || name.contains('ORDINARY')) {
      return 'savings';
    } else if (name.contains('NWD') || name.contains('DEPOSIT') || name.contains('MEMBER DEPOSIT')) {
      return 'deposit';
    } else if (name.contains('SHARES') || name.contains('CAPITAL')) {
      return 'shares';
    }
    return 'savings';
  }

  /// Set account type flags based on accountType for filtering
  void _setAccountTypeFlags(Map<String, dynamic> account) {
    // Use the AccountFilteringService to set flags instead of hardcoded logic
    AccountFilteringService.setAccountTypeFlags(account);
  }

  void _initializeFormData() {
    for (var journey in journeys) {
      _processFieldGroupForDefaults(journey.fieldGroup);
    }

    _initializeAccountFields();
  }

  /// Extract displayField KEYS and LABELS from service journey
  /// IMPORTANT: Service journey returns PRE-FILLED values - we IGNORE these values entirely
  /// We only extract:
  /// - The KEY names (e.g., productName, interestRate)
  /// - The LABELS (e.g., "Loan Type", "Interest Rate")
  /// VALUES will come PURELY from fetchLoanDetails response
  void _storeOriginalDisplayFieldTemplates() {
    _originalDisplayFieldTemplates.clear();
    _guarantorDisplayFieldTemplates.clear();
    for (var journey in journeys) {
      _extractDisplayFieldLabelsFromGroup(journey.fieldGroup);
    }
    AppLogger.info('Extracted displayField keys and labels (ignoring pre-filled values): $_originalDisplayFieldTemplates');
    AppLogger.info('Extracted guarantor display labels: $_guarantorDisplayFieldTemplates');
  }

  /// Recursively find displayField and extract ONLY keys and labels
  /// Pre-filled values from service journey are IGNORED - only labels are extracted
  /// NOTE: guarantorRequired and guarantorPending labels are stored separately
  void _extractDisplayFieldLabelsFromGroup(List<FormFieldModel> fields) {
    // Keys that should be displayed separately (not in main product info)
    const separateDisplayKeys = {'guarantorRequired', 'guarantorPending'};

    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _extractDisplayFieldLabelsFromGroup(field.fieldGroup!);
      } else if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        _extractDisplayFieldLabelsFromGroup(field.fieldArray!);
      } else if (field.key == 'displayField' &&
                 field.type == 'display' &&
                 field.responseType == 'DIGITALLOANS') {
        for (var key in field.templateOptions.keys) {
          // Skip non-display keys
          if (key == 'fetchUrl' || key == '_keyOrder' || key == 'options' || key == 'displayData') continue;

          String templateValue = field.templateOptions[key]?.toString() ?? '';
          String label = '';

          // Extract ONLY the label, ignoring the pre-filled value
          if (templateValue.contains(':')) {
            // Format: "Label: Value" or "Label: <placeholder>"
            int colonIndex = templateValue.indexOf(':');
            label = templateValue.substring(0, colonIndex).trim();
          } else {
            // No colon - use key name as label (convert camelCase to Title Case)
            label = _camelCaseToTitleCase(key);
          }

          // Store guarantor keys separately - they have their own display section
          if (separateDisplayKeys.contains(key)) {
            _guarantorDisplayFieldTemplates[key] = '$label: <$key>';
            AppLogger.info('Extracted guarantor label for $key: "$label"');
            continue;
          }

          // Store as template: "Label: <key>"
          // The <key> placeholder will be replaced with FLD response value
          _originalDisplayFieldTemplates[key] = '$label: <$key>';
          AppLogger.info('Extracted label for $key: "$label"');
        }
      }
    }
  }

  /// Convert camelCase to Title Case (e.g., "productName" -> "Product Name")
  String _camelCaseToTitleCase(String camelCase) {
    if (camelCase.isEmpty) return camelCase;
    String result = camelCase.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return result[0].toUpperCase() + result.substring(1);
  }

  /// Update displayField with values PURELY from fetchLoanDetails (FLD) response
  /// Template structure comes from service journey, but ALL VALUES come from:
  /// - fetchLoanDetails response (productName, interestRate, guarantorRequired, etc.)
  /// - checkEligibility response (maxEligibleAmount ONLY)
  /// - Calculated value (guarantorPending)
  void _updateDisplayFieldWithFldResponse(Map<String, dynamic> fldResponse, String maxEligibleAmount, int guarantorsCount) {
    for (var journey in journeys) {
      _updateDisplayFieldInGroup(journey.fieldGroup, fldResponse, maxEligibleAmount, guarantorsCount);
    }
  }

  /// Build displayField PURELY from fetchLoanDetails response values
  ///
  /// VALUE SOURCES:
  /// - maxEligibleAmount: from checkEligibility response ONLY
  /// - guarantorRequired: from FLD response (guarantorRequired field)
  /// - guarantorPending: calculated (guarantorRequired - valid guarantors entered)
  /// - ALL OTHER VALUES: from FLD response (productName, interestRate, productCode, etc.)
  ///
  /// IMPORTANT: Only displays keys that have values in FLD response or are calculated
  /// Keys in service journey that don't have FLD values are skipped (e.g., maxPeriod if not in FLD)
  void _updateDisplayFieldInGroup(List<FormFieldModel> fields, Map<String, dynamic> fldResponse, String maxEligibleAmount, int guarantorsCount) {
    AppLogger.info('Building displayField PURELY from FLD response values');
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _updateDisplayFieldInGroup(field.fieldGroup!, fldResponse, maxEligibleAmount, guarantorsCount);
      } else if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        _updateDisplayFieldInGroup(field.fieldArray!, fldResponse, maxEligibleAmount, guarantorsCount);
      } else if (field.key == 'displayField' &&
                 field.type == 'display' &&
                 field.responseType == 'DIGITALLOANS') {
        AppLogger.info('Building displayField with FLD response: $fldResponse');
        AppLogger.info('maxEligibleAmount from eligibility: $maxEligibleAmount');

        // Calculate pending guarantors (guarantorRequired from FLD - valid guarantors entered)
        List<dynamic> existingGuarantors = formData['guarantors'] ?? [];
        int validGuarantors = existingGuarantors.where((g) =>
            g is Map && g['guarantorPhone'] != null && g['guarantorPhone'].toString().isNotEmpty
        ).length;
        int pendingGuarantors = guarantorsCount - validGuarantors;
        if (pendingGuarantors < 0) pendingGuarantors = 0;

        // Build substitution map - ALL values from FLD response + calculated values
        Map<String, String> substitutionValues = {};

        // 1. Add ALL FLD response values first (productName, interestRate, guarantorRequired, etc.)
        fldResponse.forEach((key, value) {
          if (value != null) {
            substitutionValues[key] = value.toString();
          }
        });

        // 2. Add maxEligibleAmount from checkEligibility response
        substitutionValues['maxEligibleAmount'] = maxEligibleAmount;

        // 3. Add calculated guarantorPending
        substitutionValues['guarantorPending'] = pendingGuarantors.toString();

        // 4. Ensure guarantorRequired uses the value from FLD response
        substitutionValues['guarantorRequired'] = guarantorsCount.toString();

        AppLogger.info('Substitution values (from FLD + eligibility): $substitutionValues');

        // Clear ALL existing templateOptions except fetchUrl - rebuild from scratch
        List<String> allKeysToRemove = field.templateOptions.keys
            .where((k) => k != 'fetchUrl')
            .toList();
        for (var key in allKeysToRemove) {
          field.templateOptions.remove(key);
        }

        // Only add keys that have values in substitutionValues (from FLD response or calculated)
        // This filters out keys like maxPeriod that are in service journey but NOT in FLD response
        for (var templateKey in _originalDisplayFieldTemplates.keys) {
          // Skip if no value available for this key in FLD response or calculated values
          if (!substitutionValues.containsKey(templateKey)) {
            AppLogger.info('Skipping $templateKey - no value in FLD response');
            continue;
          }

          String templateStr = _originalDisplayFieldTemplates[templateKey] ?? '';

          // Find all <placeholder> and replace with FLD response values
          RegExp placeholderRegex = RegExp(r'<(\w+)>');
          String substitutedStr = templateStr.replaceAllMapped(placeholderRegex, (match) {
            String placeholderKey = match.group(1) ?? '';
            return substitutionValues[placeholderKey] ?? '';
          });

          field.templateOptions[templateKey] = substitutedStr;
        }

        // Add guarantorRequired and guarantorPending to templateOptions using labels from journey config
        // These are displayed separately in the DynamicForm widget
        for (var guarantorKey in _guarantorDisplayFieldTemplates.keys) {
          if (!substitutionValues.containsKey(guarantorKey)) continue;

          String templateStr = _guarantorDisplayFieldTemplates[guarantorKey] ?? '';

          // Find all <placeholder> and replace with values
          RegExp placeholderRegex = RegExp(r'<(\w+)>');
          String substitutedStr = templateStr.replaceAllMapped(placeholderRegex, (match) {
            String placeholderKey = match.group(1) ?? '';
            return substitutionValues[placeholderKey] ?? '';
          });

          field.templateOptions[guarantorKey] = substitutedStr;
        }

        AppLogger.info('DisplayField built from FLD response: ${field.templateOptions}');
      }
    }
  }

  /// Get balance enquiry filters in AccountFilteringService format
  List<String> _getBalanceEnquiryFilters() {
    String enquiryType = widget.balanceEnquiryType ?? widget.serviceCode;

    switch (enquiryType) {
      case 'SCBE': // Share Capital Balance Enquiry
      case 'ASCB':
        return ['isShareCapital=Yes'];

      case 'SBE': // Savings Balance Enquiry
        return ['isSavingsAccount=Yes'];

      case 'NWDB': // NWD Balance Enquiry
        return ['isNWD=Yes'];

      case 'LB': // Loan Balance Enquiry
      case 'ALB':
        return ['isLoanAccount=Yes'];

      case 'ASB': // All Balances Enquiry - show all accounts
        return []; // No filters - show all accounts

      case 'ANB': // All Balances Enquiry - show all accounts
        return []; // No filters - show all accounts

      default:
      // Fallback - show all accounts
        return []; // No filters - show all accounts
    }
  }

  void _initializeAccountFields() {
    for (var journey in journeys) {
      _initializeAccountFieldsInGroup(journey.fieldGroup);
    }
  }

  void _prefillWithPreSelectedAccount() {
    // Prefill form with loan account details when preSelectedAccount is provided
    // This happens when navigating from "Repay Loan" button on active loans
    if (widget.preSelectedAccount == null) {
      return;
    }

    final account = widget.preSelectedAccount as Map<String, dynamic>;
    final accountNo = account['accountNo']?.toString() ?? '';
    final accountName = account['accountName']?.toString() ?? '';
    final balance = account['balance']?.toString() ?? '0';

    AppLogger.info(
      'Prefilling form with preSelectedAccount: accountNo=$accountNo, accountName=$accountName, balance=$balance',
    );

    // Set account-related fields in formData
    // Try different field key variations that might be used in the journey
    final accountKeyVariations = ['accountNo', 'accNo', 'loanAccountNo', 'loanAccountNumber', 'ownAccNo'];
    final nameKeyVariations = ['accountName', 'accName', 'loanAccountName', 'name'];
    final balanceKeyVariations = ['balance', 'outstandingBalance', 'loanBalance', 'amount'];

    for (var key in accountKeyVariations) {
      if (accountNo.isNotEmpty) {
        formData[key] = accountNo;
      }
    }

    for (var key in nameKeyVariations) {
      if (accountName.isNotEmpty) {
        formData[key] = accountName;
      }
    }

    for (var key in balanceKeyVariations) {
      if (balance.isNotEmpty) {
        formData[key] = balance;
      }
    }

    // Carousel deposit (lockAccountSelection + transactionType == 'deposit'),
    // auto-select "Own account" txnType and hide the radio selection
    if (widget.transactionType == 'deposit' && widget.lockAccountSelection) {
      // Find the txnType radio field's first option key (the "Own account" option)
      final ownAccountKey = _findOwnAccountTxnTypeKey();
      formData['txnType'] = ownAccountKey ?? widget.serviceCode;
      _lockedFieldKeys.add('txnType');
      AppLogger.info('Carousel deposit: auto-set txnType to ${formData['txnType']}, locking txnType radio');
    } else if (widget.serviceCode == 'STKLOANS') {
      // Set transaction type for loan repayment
      formData['txnType'] = 'STKLOANS';
    }

    AppLogger.info('Form prefilled with account details: $formData');
  }

  /// Resolve select field codes to display labels (e.g., bank code -> bank name)
  void _resolveSelectFieldLabels(Map<String, dynamic> data) {
    for (var journey in journeys) {
      _resolveSelectLabelsInFields(journey.fieldGroup, data);
    }
  }

  void _resolveSelectLabelsInFields(List<FormFieldModel> fields, Map<String, dynamic> data) {
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _resolveSelectLabelsInFields(field.fieldGroup!, data);
      }
      if (field.type == 'select' &&
          field.responseType != null &&
          !field.responseType!.contains('ACCOUNTS') &&
          data.containsKey(field.key)) {
        final options = field.templateOptions['options'] as List<dynamic>?;
        if (options != null) {
          final currentValue = data[field.key]?.toString();
          for (var option in options) {
            final optId = option['id']?.toString() ?? option['key']?.toString() ?? option['value']?.toString() ?? '';
            if (optId == currentValue) {
              final label = option['label']?.toString() ??
                  option['name']?.toString() ??
                  option['value']?.toString();
              if (label != null && label != currentValue) {
                data[field.key] = label;
                AppLogger.info('Resolved select field ${field.key}: $currentValue -> $label');
              }
              break;
            }
          }
        }
      }
    }
  }

  /// Find the "Own account" option key from the txnType radio field in the journey config.
  /// Returns the first option's key (which represents "Own account") or null if not found.
  String? _findOwnAccountTxnTypeKey() {
    for (var journey in journeys) {
      final result = _findTxnTypeKeyInFields(journey.fieldGroup);
      if (result != null) return result;
    }
    return null;
  }

  String? _findTxnTypeKeyInFields(List<FormFieldModel> fields) {
    for (var field in fields) {
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        final result = _findTxnTypeKeyInFields(field.fieldGroup!);
        if (result != null) return result;
      }
      if (field.key == 'txnType' && field.type == 'radio') {
        final options = field.templateOptions['options'] as List<dynamic>?;
        if (options != null && options.isNotEmpty) {
          // Return the first option's key (typically "Own account")
          return options.first['key']?.toString();
        }
      }
    }
    return null;
  }

  void _initializeAccountFieldsInGroup(List<FormFieldModel> fields) {
    for (var field in fields) {
      if (field.fieldGroup != null) {
        _initializeAccountFieldsInGroup(field.fieldGroup!);
      } else if (field.fieldArray != null) {
        _initializeAccountFieldsInGroup(field.fieldArray!);
      } else if (field.responseType != null &&
          (field.responseType!.contains('ACCOUNTS') || field.responseType == 'ACCOUNTS') ||
          field.key == 'ownAccNo' ||
          field.key == 'accNo') {
        _filterAndPopulateAccountField(field);
      }
    }
  }

  void _filterAndPopulateAccountField(FormFieldModel field) {
    if (allAccounts.isEmpty) {
      return;
    }

    List<Map<String, dynamic>> filteredAccounts;
    final bool isFromAccountField = widget.transactionType == 'inter_account_transfer' &&
        (field.key == 'accNo' || field.key == 'ownAccNo' ||
            field.templateOptions['label']?.toString().toLowerCase().contains('from') == true);

    final bool isToAccountField = widget.transactionType == 'inter_account_transfer' &&
        (field.key != 'accNo' && field.key != 'ownAccNo') &&
        (field.responseType != null && field.responseType!.contains('ACCOUNTS'));


    if (widget.lockAccountSelection && isFromAccountField) {
      filteredAccounts = [widget.preSelectedAccount];
    } else if (isToAccountField && widget.preSelectedAccount != null) {
      final fromAccountNo = widget.preSelectedAccount['accountNo']?.toString();
      filteredAccounts = allAccounts
          .where((acc) => acc['accountNo']?.toString() != fromAccountNo)
          .toList()
          .cast<Map<String, dynamic>>();
    } else if (widget.lockAccountSelection && widget.preSelectedAccount != null) {
      filteredAccounts = [widget.preSelectedAccount];
    } else if (_isBalanceEnquiry() && field.key == 'accNo') {
      List<String> balanceEnquiryFilters = _getBalanceEnquiryFilters();
      Map<String, dynamic> fieldData = {
        'defaultValues': balanceEnquiryFilters,
        'responseType': 'ACCOUNTS',
      };
      filteredAccounts = AccountFilteringService.filterAccountsForField(
        allAccounts,
        fieldData,
      );
    } else if (field.responseType == 'ACCOUNTS' || (field.responseType != null && field.responseType!.contains('ACCOUNTS'))) {
      Map<String, dynamic> fieldData = {
        'defaultValues': field.defaultValues,
        'responseType': field.responseType,
      };

      // For inter-account transfers (IATOW, IATOT, IAT), exclude source account from destination dropdown
      if ((widget.serviceCode == 'IATOW' || widget.serviceCode == 'IATOT' || widget.serviceCode == 'IAT')
          && field.key == 'otherAccNo') {
        String? sourceAccount = formData['accNo']?.toString();
        if (sourceAccount != null && sourceAccount.isNotEmpty) {
          AppLogger.info('Inter-account transfer: Excluding source account $sourceAccount from destination options');
          fieldData['filterExpression'] = 'exclude:model.accNo';
          fieldData['currentFormData'] = formData;
        }
      }

      filteredAccounts = AccountFilteringService.filterAccountsForField(
        allAccounts,
        fieldData,
      );
    } else {
      filteredAccounts = allAccounts.cast<Map<String, dynamic>>();
    }

    List<Map<String, dynamic>> options =
    AccountFilteringService.createAccountOptions(filteredAccounts);
    field.templateOptions['options'] = options;

    // Store the accounts options (not raw accounts) so account name resolution works correctly
    fieldAccountOptions[field.key] = options;

    // Show full-screen "No Eligible Accounts" if client-side filtering returned no matches
    // Skip this check for locked/pre-selected accounts since those are intentionally constrained
    if (options.isEmpty &&
        !widget.lockAccountSelection &&
        field.defaultValues != null &&
        field.defaultValues!.isNotEmpty) {
      final fieldLabel = field.templateOptions['label']?.toString() ?? field.key;
      AppLogger.info('No eligible accounts for field "$fieldLabel" '
          'with filters: ${field.defaultValues}');
      setState(() {
        _isNoEligibleAccountsError = true;
        errorMessage =
            'We couldn\'t find a valid account for this transaction. '
            'Please contact your SACCO for assistance.';
      });
      return;
    }

    if (widget.lockAccountSelection && isFromAccountField) {
      // Auto-select the pre-selected "From Account".
      String accountNo = widget.preSelectedAccount['accountNo']?.toString() ?? '';
      if (accountNo.isNotEmpty) {
        setState(() {
          formData[field.key] = accountNo;
        });
        _onFieldChanged(field.key, accountNo);
      }
    } else if (filteredAccounts.length == 1) {
      String accountNo = filteredAccounts[0]['accountNo']?.toString() ?? '';
      if (accountNo.isNotEmpty) {
        setState(() {
          formData[field.key] = accountNo;
        });
        _onFieldChanged(field.key, accountNo);
      }
    }
  }

  void _processFieldGroupForDefaults(List<FormFieldModel> fields) {
    for (var field in fields) {
      if (field.fieldGroup != null) {
        _processFieldGroupForDefaults(field.fieldGroup!);
      } else if (field.fieldArray != null) {
        _processFieldGroupForDefaults(field.fieldArray!);
      } else {
        if (field.defaultValue != null) {
          if (!formData.containsKey(field.key)) {
            formData[field.key] = field.defaultValue;
          }
        }
      }
    }
  }

  void _onFieldChanged(String key, dynamic value) {
    TokenRefreshService.instance.recordUserInteraction();
    setState(() {
      formData[key] = value;

      if (key.toLowerCase() == 'eloancode' || key.toLowerCase() == 'loantype') {
        try {
          FormFieldModel? loanField;

          // Helper function to find the field definition recursively
          void findField(List<FormFieldModel> fields) {
            for (var field in fields) {
              if (field.key == key) {
                loanField = field;
                return;
              }
              if (field.fieldGroup != null) findField(field.fieldGroup!);
            }
          }

          // Search through all journeys for the field metadata
          for (var journey in journeys) {
            findField(journey.fieldGroup);
            if (loanField != null) break;
          }

          if (loanField != null && loanField!.templateOptions['options'] != null) {
            List options = loanField!.templateOptions['options'];

            // Find the option label that matches the selected value
            var selectedOption = options.firstWhere(
                  (opt) => opt['value']?.toString() == value?.toString() ||
                  opt['accountNo']?.toString() == value?.toString(),
              orElse: () => null,
            );

            if (selectedOption != null) {
              formData['eloanName'] = selectedOption['label'] ?? selectedOption['accountName'] ?? value;
              AppLogger.info('✅ Mapped $value to Name: ${formData['eloanName']}');
            }else{
              formData.remove('eloaName');
              formData.remove('eloanName');
              AppLogger.warning('⚠️ No name mapping found for code: $value');
            }
          }
        } catch (e) {
          AppLogger.error('Error mapping loan name: $e');
        }
      }

      if (key == 'txnType' && value != 'WDO' &&
          (widget.serviceCode == 'WD' || widget.serviceCode == 'WDO')) {
        _populateMyNumberWithdrawal();
      }

      // Clear description and related fields when user switches to "withdrawal to other"
      if (key == 'txnType' && value == 'WDO' &&
          (widget.serviceCode == 'WD' || widget.serviceCode == 'WDO')) {
        _clearMyNumberWithdrawalData();
      }

      // For inter-account transfers, when source account changes, re-filter destination accounts
      if ((widget.serviceCode == 'IATOW' || widget.serviceCode == 'IATOT' || widget.serviceCode == 'IAT')
          && key == 'accNo' && value != null) {
        AppLogger.info('Inter-account transfer: Source account changed to $value, re-filtering destination accounts');
        _refreshDestinationAccountsForInterAccountTransfer();
      }

      // Check if there are email validation errors after field changes
      _checkEmailValidationErrors();
    });
  }

  // Check for email validation errors across all dynamic forms
  void _checkEmailValidationErrors() {
    bool hasErrors = false;

    // Check all form data for email fields and validate them
    formData.forEach((key, value) {
      if (key.toLowerCase().contains('email') &&
          value != null &&
          value.toString().isNotEmpty) {
        // Basic email validation
        final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.toString())) {
          hasErrors = true;
        }
      }
    });

    _hasEmailValidationErrors = hasErrors;
  }

  String _getAppBarTitle() {
    // Tiles with eloanCode -> always use the tile title from dashboard/services screen
    if (widget.eloanCode != null && widget.eloanCode!.isNotEmpty &&
        widget.loanTitle != null && widget.loanTitle!.isNotEmpty) {
      return widget.loanTitle!;
    }

    // IDL (Digital Loans) appBar -> get loan title from dashboard tile if provided
    if (widget.serviceCode == 'IDL' && widget.loanTitle != null && widget.loanTitle!.isNotEmpty) {
      return widget.loanTitle!;
    }

    // ASL (Secured Loans) -> use loan title from dashboard or appBarLabel
    if (widget.serviceCode == 'ASL' && widget.loanTitle != null && widget.loanTitle!.isNotEmpty) {
      return widget.loanTitle!;
    }

    if (journeys.isEmpty) return 'Transaction';

    // Check for appBarLabel in tabbed journey configuration
    FormJourneyModel? tabbedJourney = journeys.where((j) => j.isTabbed).firstOrNull;
    if (tabbedJourney != null && tabbedJourney.appBarLabel != null) {
      return tabbedJourney.appBarLabel!;
    }

    // Check for appBarLabel in stepper journey configuration
    FormJourneyModel? stepperJourney = journeys.firstWhere(
      (j) => j.isStepper,
      orElse: () => journeys.first,
    );

    // For stepper journeys, use appBarLabel if available
    if (stepperJourney.isStepper && stepperJourney.appBarLabel != null) {
      return stepperJourney.appBarLabel!;
    }

    // Fallback to checking first field group's label
    if (journeys[0].fieldGroup.isNotEmpty) {
      var firstGroup = journeys[0].fieldGroup[0];
      if (firstGroup.templateOptions.containsKey('label')) {
        return firstGroup.templateOptions['label'];
      }
    }

    return 'Form Journey';
  }

  void _showGenericConfirmationDialog() async {
    AppLogger.info('=== SHOWING ENHANCED CONFIRMATION DIALOG ===');
    AppLogger.info('Service Code: ${widget.serviceCode}');
    AppLogger.info('Form Data Keys: ${formData.keys.toList()}');
    AppLogger.info('Validated Customer Name: $_validatedCustomerName');

    // Check if we have template config
    if (messageTemplateConfig?.confirmationTemplate == null) {
      AppLogger.error('⛔ No confirmation template not set in db -> showing fallback');

      _showFallbackConfirmationDialog();
      return;
    }

    AppLogger.info('Confirmation template from db found... ');
    AppLogger.info('Template Title: ${messageTemplateConfig!.confirmationTemplate!.title}');
    AppLogger.info('Template Subtitle: ${messageTemplateConfig!.confirmationTemplate!.subtitle}');
    AppLogger.info('Template Fields (${messageTemplateConfig!.confirmationTemplate!.fields.length}):');


    Map<String, dynamic> displayData = Map.from(formData);

    if (displayData.containsKey('eloanName') && displayData['eloanName'] != null) {
      String readableName = displayData['eloanName'];

      final loanKeys = ['eloanCode', 'eLoanCode', 'loanType', 'loanProduct', 'productName'];

      for (var key in loanKeys) {
        if (displayData.containsKey(key)) {
          displayData[key] = readableName; // Swap Code for Name
          AppLogger.info('UI Override: Setting $key to "$readableName" for display');
        }
      }
    }else{
      AppLogger.warning('Fallback: No readable name found, displaying loan code.');
    }

    // Handle description field display for withdrawal transactions
    if (widget.serviceCode == 'WD' || widget.serviceCode == 'WDO') {
      String? txnType = displayData['txnType']?.toString();
      if (txnType == 'WD') {
        // Withdrawal to own number - show 'My Number'
        displayData['description'] = 'My Number';
        AppLogger.info('UI Override: Setting description to "My Number" for WD');
      } else if (txnType == 'WDO') {
        // Withdrawal to other - show name if found, otherwise keep phone number
        if (displayData.containsKey('recipientName') &&
            displayData['recipientName'] != null &&
            displayData['recipientName'].toString().isNotEmpty) {
          displayData['description'] = displayData['recipientName'];
          AppLogger.info('UI Override: Setting description to recipientName "${displayData['recipientName']}" for WDO');
        }
        // If recipientName not set, description keeps the phone number (default behavior)
      }
    }

    // Handle description field display for airtime transactions
    if (widget.serviceCode == 'AT') {
      String? txnType = displayData['txnType']?.toString();
      if (txnType == 'AT') {
        // Airtime to own number - show 'My Number'
        displayData['description'] = 'My Number';
        AppLogger.info('UI Override: Setting description to "My Number" for AT (my phone)');
      }
      // For ATO, description already contains the entered phone number
    }

    _resolveSelectFieldLabels(displayData);

    final serviceChargeFlag = await SharedPreferencesHelper.getShowServiceCharge();
    final shouldShowServiceCharge = serviceChargeFlag == 1;

    // Use displayData here instead of formData so the generator picks up the Name
    Map<String, String> transactionDetails = messageTemplateConfig!
        .confirmationTemplate!
        .generateTransactionDetails(displayData,
        fieldAccountOptions: fieldAccountOptions);

    AppLogger.info('Generated transaction details: $transactionDetails');

    // Show both name and number for validated customer name in withdrawal services
    if ((widget.serviceCode == 'WD' || widget.serviceCode == 'WDO') &&
        _validatedCustomerName != null &&
        _validatedCustomerName!.isNotEmpty) {

      AppLogger.info('Withdrawal confirmation with customer name: $_validatedCustomerName');

      for (String key in transactionDetails.keys.toList()) {
        bool isPhoneField = key.toLowerCase().contains('phone') ||
            key.toLowerCase().contains('recipient') ||
            key.toLowerCase().contains('description');

        if (isPhoneField) {
          String originalValue = transactionDetails[key]!;
          String enhancedValue = '$originalValue - $_validatedCustomerName';
          transactionDetails[key] = enhancedValue;
          break;
        }
      }
      // Alternatively, check common field names
      final commonPhoneFieldNames = ['Receiver Phone Number', 'Recipient', 'Receiver Phone', 'Mobile Number', 'Receiver Mobile Number'];
      for (String fieldName in commonPhoneFieldNames) {
        if (transactionDetails.containsKey(fieldName)) {
          String originalValue = transactionDetails[fieldName]!;
          String formattedName = CustomerValidationService.formatCustomerName(_validatedCustomerName!);
          String enhancedValue = '$originalValue - $formattedName';

          // transactionDetails[fieldName] = enhancedValue;
          AppLogger.info('✅ Enhanced $fieldName field: "$originalValue" → "$enhancedValue"');
          break;
        }
      }
    }

    // Extract the journey label from the service journey
    String journeyLabel = _extractJourneyLabel();

    // Template with journey label as title
    ConfirmationTemplate updatedTemplate = ConfirmationTemplate(
      title: journeyLabel,
      subtitle: messageTemplateConfig!.confirmationTemplate!.subtitle,
      fields: messageTemplateConfig!.confirmationTemplate!.fields,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GenericConfirmationDialog(
        template: updatedTemplate,
        transactionDetails: transactionDetails,
        formData: formData,
        accounts: allAccounts,
        serviceCode: widget.serviceCode,
        showServiceCharge: shouldShowServiceCharge,
        onCancel: () {
          AppLogger.info('User cancelled transaction');
          Navigator.pop(context);
        },
        onContinue: () {
          AppLogger.info('User confirmed transaction');
          Navigator.pop(context);
          setState(() {
            isProcessing = true;
          });
          _processTransaction();
        },
      ),
    );
  }

  String _extractJourneyLabel() {
    try {
      if (journeys.isEmpty) {
        return 'Confirm Transaction'; // Fallback
      }

      // Confirmation screen title: extract from top-level label in journey
      for (var journey in journeys) {
        if (journey.type == 'stepper' && journey.fieldGroup.isNotEmpty) {
          for (var topLevelFieldGroup in journey.fieldGroup) {
            if (topLevelFieldGroup.templateOptions.containsKey('label') &&
                topLevelFieldGroup.templateOptions['label'] != null &&
                topLevelFieldGroup.templateOptions['label']
                    .toString()
                    .isNotEmpty) {
              String label =
                  topLevelFieldGroup.templateOptions['label'].toString();
              AppLogger.info('Found TOP-LEVEL journey label: $label');
              return label;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error extracting top-level journey label: $e');
    }

    AppLogger.warning('❌ No top-level journey label found, using fallback');
    return 'Confirm Transaction'; // Fallback title
  }

  void _onContinue() async {
    // Validate form
    if (!_validateForm()) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    if (_hasEmailValidationErrors || _hasFormValidationErrors) {
      _showErrorSnackBar('Cannot proceed due to validation errors. Please review your inputs.');
      return;
    }

    // Check if amount field has eligibility validation error
    if (formData.containsKey('amt') && _hasEligibilityError()) {
      _showEligibilityErrorDialog();
      return;
    }

    // Validate guarantors if this is an IDL stepper journey on Screen 2
    FormJourneyModel? stepperJourney = journeys.firstWhere(
      (j) => j.isStepper,
      orElse: () => journeys.isNotEmpty ? journeys.first : FormJourneyModel(type: 'form', fieldGroup: []),
    );

    if (stepperJourney.isStepper && _currentStepIndex > 0) {
      // We're on Screen 2, validate guarantors
      // Get guarantors required from the displayField or formData
      int guarantorsRequired = _getGuarantorsRequired();
      List<dynamic> guarantors = formData['guarantors'] ?? [];

      // Count validated guarantors (those with isValidated == true)
      int validatedGuarantorsCount = guarantors.where((g) =>
        g != null &&
        g is Map &&
        (g as Map).isNotEmpty &&
        g['isValidated'] == true
      ).length;

      if (guarantorsRequired > 0 && validatedGuarantorsCount < guarantorsRequired) {
        int remaining = guarantorsRequired - validatedGuarantorsCount;
        String message = remaining == 1
            ? '1 more guarantor is required'
            : '$remaining more guarantors are required';
        _showErrorSnackBar(message);
        return;
      }

      // Validate PIN is entered
      String pin = formData['cmp']?.toString() ?? '';
      if (pin.isEmpty) {
        _showErrorSnackBar('Please enter your PIN');
        return;
      }
      if (pin.length != 4) {
        _showErrorSnackBar('PIN must be 4 digits');
        return;
      }
    }

    // Show confirmation dialog before submitting IDL loan
    if (widget.serviceCode == 'IDL') {
      _showIdlConfirmationDialog();
      return;
    }

    setState(() {
      isProcessing = true;
    });

    // PIN verification successful - reset retry mode
    setState(() {
      _isInPinRetryMode = false;
    });

    // Use generic dialog for all transactions
    if (_shouldSkipConfirmation()) {
      _processTransactionDirectly();
      return;
    }
    final serviceChargeFlag =
        await SharedPreferencesHelper.getShowServiceCharge();
    // Check the service charge flag value
    if (serviceChargeFlag == 1) {
      try {
        final serviceChargeService = ServiceChargeService();

        // Get txnType from formData (from journey config)
        String txnType = formData['txnType']?.toString() ??
            widget.serviceCode;
        String amount = formData['amt']?.toString() ?? '0';
        final serviceChargeData = await serviceChargeService.getServiceCharge(
          txnType: txnType,
          amount: amount,
          context: context,
        );

        if (serviceChargeData == null) {
          formData['serviceChargeData'] = null;
          formData['serviceChargeAmount'] = 0.0;
        } else if (!ServiceChargeService.isValidServiceCharge(
            serviceChargeData)) {
          formData['serviceChargeData'] = null;
          formData['serviceChargeAmount'] = 0.0;
        } else {
          // Extract service charge amount
          double chargeAmount = 0.0;
          if (serviceChargeData.containsKey('serviceCharge')) {
            chargeAmount = double.tryParse(
                serviceChargeData['serviceCharge'].toString()) ??
                0.0;
          } else if (serviceChargeData.containsKey('charge')) {
            chargeAmount =
                double.tryParse(serviceChargeData['charge'].toString()) ?? 0.0;
          } else if (serviceChargeData.containsKey('fee')) {
            chargeAmount =
                double.tryParse(serviceChargeData['fee'].toString()) ?? 0.0;
          }
          formData['serviceChargeData'] = serviceChargeData;
          formData['serviceChargeAmount'] = chargeAmount;

        }
      } catch (e) {
        formData['serviceChargeData'] = null;
        formData['serviceChargeAmount'] = 0.0;
      }
    } else {
      formData['serviceChargeData'] = null;
      formData['serviceChargeAmount'] = 0.0;
      formData.remove('serviceChargeData');
      formData.remove('serviceChargeAmount');
    }
    setState(() {
      isProcessing = false;
    });
    _showGenericConfirmationDialog();
  }

  bool _shouldSkipConfirmation() {
    if (enquiryServiceCodes.contains(widget.serviceCode)) {
      return true;
    }

    if (widget.balanceEnquiryType != null &&
        enquiryServiceCodes.contains(widget.balanceEnquiryType)) {
      return true;
    }

    // Skip generic confirmation screen for IDL -> uses its own confirmation dialog
    if (widget.serviceCode == 'IDL') {
      return true;
    }

    return false;
  }

  void _showIdlConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ClientThemeManager().colors;
    final fontFamily = ClientThemeManager().currentClientConfig.fontFamily;

    // Get loan details for display
    String productName = formData['productName']?.toString() ??
        formData['eloanCode']?.toString() ?? formData['eLoanCode']?.toString() ?? 'Digital Loan';
    String loanAmount = formData['amt']?.toString() ?? '0';
    String repaymentPeriod = formData['repaymentPeriod']?.toString() ?? '';
    int guarantorsCount = formData['guarantorsCount'] ?? 0;
    List<dynamic> guarantors = formData['guarantors'] ?? [];
    int validatedGuarantors = guarantors.where((g) =>
        g is Map && g['isValidated'] == true).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              size: 36,
                              color: Colors.white,
                            ),
                          ).animate()
                            .scale(duration: 400.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 20),
                          Text(
                            'Confirm Loan Application',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ).animate()
                            .fadeIn(duration: 400.ms, delay: 150.ms)
                            .slideY(begin: 0.3),
                          const SizedBox(height: 8),
                          Text(
                            'Please review your loan details before submitting',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.75),
                              fontFamily: fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ).animate()
                            .fadeIn(duration: 400.ms, delay: 250.ms),
                        ],
                      ),
                    ),

                    // Loan details card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[850]
                            : colors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildLoanDetailRow(
                            'Product',
                            productName,
                            Icons.account_balance_outlined,
                            colors,
                            isDark,
                            fontFamily,
                          ),
                          Divider(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            height: 20,
                          ),
                          _buildLoanDetailRow(
                            'Amount',
                            'KES ${NumberFormat('#,##0').format(int.tryParse(loanAmount) ?? 0)}',
                            Icons.payments_outlined,
                            colors,
                            isDark,
                            fontFamily,
                          ),
                          if (repaymentPeriod.isNotEmpty) ...[
                            Divider(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              height: 20,
                            ),
                            _buildLoanDetailRow(
                              'Repayment Period',
                              '$repaymentPeriod ${int.tryParse(repaymentPeriod) == 1 ? "month" : "months"}',
                              Icons.calendar_today_outlined,
                              colors,
                              isDark,
                              fontFamily,
                            ),
                          ],
                          if (guarantorsCount > 0) ...[
                            Divider(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              height: 20,
                            ),
                            _buildLoanDetailRow(
                              'Guarantors',
                              '$validatedGuarantors of $guarantorsCount validated',
                              Icons.people_outline,
                              colors,
                              isDark,
                              fontFamily,
                            ),
                          ],
                        ],
                      ),
                    ).animate()
                      .fadeIn(duration: 400.ms, delay: 350.ms)
                      .slideY(begin: 0.2),

                    const SizedBox(height: 24),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _processTransactionDirectly();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClientThemeManager().colors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate()
                      .fadeIn(duration: 400.ms, delay: 450.ms)
                      .slideY(begin: 0.3),
                  ],
                ),
              ).animate()
                .scale(
                  duration: 350.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.9, 0.9),
                )
                .fadeIn(duration: 250.ms),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoanDetailRow(
    String label,
    String value,
    IconData icon,
    ClientColorPalette colors,
    bool isDark,
    String? fontFamily,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _processTransactionDirectly() {
    setState(() {
      isProcessing = true;
    });

    _processTransaction();
  }

  bool _validateForm() {
    List<String> missingFields = [];
    bool isValid = true;

    for (var journey in journeys) {
      if (!_recursiveValidate(journey.fieldGroup, missingFields)) {
        isValid = false;
      }
    }

    if (!isValid) {
      AppLogger.info(
          "Validation failed. Missing fields: ${missingFields.join(', ')}");
    }

    return isValid;
  }

  bool _recursiveValidate(
      List<FormFieldModel> fields, List<String> missingFields) {
    bool isValid = true;
    for (var field in fields) {
      if (_shouldSkipFieldValidation(field)) {
        continue;
      }

      // Recurse into nested structures first
      if (field.fieldGroup != null) {
        if (!_recursiveValidate(field.fieldGroup!, missingFields)) {
          isValid = false;
        }
      } else if (field.fieldArray != null) {
        // For array fields (like guarantors), DON'T recurse into fieldArray
        // as those are modal input fields, not persistent form data.
        // Instead, validate the array data itself.
        if (field.type == 'array') {
          bool isRequired = field.templateOptions['required'] == 'true' ||
              field.templateOptions['required'] == true;
          if (isRequired) {
            // For guarantors field, skip validation if no guarantors are required
            if (field.key == 'guarantors') {
              int guarantorsCount = formData['guarantorsCount'] ?? 0;
              if (guarantorsCount == 0) {
                // No guarantors required, skip validation
                continue;
              }
            }
            List<dynamic> arrayData = formData[field.key] ?? [];
            if (arrayData.isEmpty) {
              AppLogger.info("Missing required array field: ${field.key}");
              missingFields.add(field.key);
              isValid = false;
            }
          }
        }
        // Skip recursing into fieldArray - those are modal fields
      } else {
        // This is a leaf node, validate it.
        bool isRequired = field.templateOptions['required'] == 'true' ||
            field.templateOptions['required'] == true;
        if (isRequired) {
          if (!formData.containsKey(field.key) ||
              formData[field.key] == null ||
              formData[field.key].toString().isEmpty) {
            AppLogger.info("Missing required field: ${field.key}");
            missingFields.add(field.key);
            isValid = false;
          }
        }
      }
    }
    return isValid;
  }

  bool _shouldSkipFieldValidation(FormFieldModel field) {
    if (field.hide == true) return true;

    // Skip validation for hidden fields based on hideExpression
    if (field.hideExpression != null) {
      return _evaluateHideExpression(field.hideExpression!, formData);
    }

    return false;
  }

  /// Get the number of guarantors required from formData
  /// This value is set from the FLD (Fetch Loan Details) response
  int _getGuarantorsRequired() {
    // First check formData['guarantorsCount'] which is set from FLD response
    if (formData.containsKey('guarantorsCount') && formData['guarantorsCount'] != null) {
      return int.tryParse(formData['guarantorsCount'].toString()) ?? 0;
    }

    // Fallback: try to extract from displayField's templateOptions
    for (var journey in journeys) {
      int count = _extractGuarantorsRequiredFromFields(journey.fieldGroup);
      if (count > 0) return count;
    }

    return 0;
  }

  /// Helper to extract guarantorsRequired from displayField in nested fields
  int _extractGuarantorsRequiredFromFields(List<FormFieldModel> fields) {
    for (var field in fields) {
      if (field.type == 'display' && field.responseType == 'DIGITALLOANS') {
        final templateOptions = field.templateOptions;
        if (templateOptions.containsKey('guarantorRequired')) {
          String value = templateOptions['guarantorRequired']?.toString() ?? '';
          // Format: "Guarantor(s) Required: X"
          final colonIndex = value.indexOf(':');
          if (colonIndex > 0) {
            String numStr = value.substring(colonIndex + 1).trim();
            return int.tryParse(numStr) ?? 0;
          }
        }
      }

      // Recurse into nested structures
      if (field.fieldGroup != null) {
        int count = _extractGuarantorsRequiredFromFields(field.fieldGroup!);
        if (count > 0) return count;
      }
    }
    return 0;
  }

  bool _evaluateHideExpression(
      String expression, Map<String, dynamic> formData) {
    try {
      String evaluatedExpression = expression;

      // Replace model.fieldName with actual values
      RegExp regex = RegExp(r'model\.(\w+)');
      evaluatedExpression =
          evaluatedExpression.replaceAllMapped(regex, (match) {
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

      // Handle == comparison
      if (evaluatedExpression.contains('==')) {
        evaluatedExpression = evaluatedExpression.replaceAll('===', '==');
        List<String> parts =
            evaluatedExpression.split('==').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          String left = parts[0].replaceAll("'", "");
          String right = parts[1].replaceAll("'", "");
          return left == right;
        }
      }

      // Handle negation
      if (evaluatedExpression.startsWith('!')) {
        String value = evaluatedExpression.substring(1).trim();
        if (value == 'null') {
          return true;
        } else if (value.isEmpty || value == "''") {
          return true;
        } else {
          return false;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('evaluating hideExpression: $expression, Error: $e');
      return false;
    }
  }

  bool _hasEligibilityError() {
    // Check if the amount field has an eligibility validation error
    // This is set by the dynamic form when eligibility check fails
    final amountError = formData['_amountEligibilityError'];
    final eligibleAmount = formData['_eligibleAmount'];

    if (amountError == true && eligibleAmount != null) {
      return true;
    }

    return false;
  }

  void _showEligibilityErrorDialog() {
    final eligibleAmount = formData['_eligibleAmount'] ?? 0;
    final enteredAmount = formData['amt'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colors = ClientThemeManager().colors;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colors.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eligibility Limit Exceeded',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The amount you entered exceeds your eligible limit.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount Entered:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          'KES ${NumberFormat('#,##0').format(enteredAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: colors.error.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Maximum Eligible:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          'KES ${NumberFormat('#,##0').format(eligibleAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please reduce the amount to ${NumberFormat('#,##0').format(eligibleAmount)} or less to proceed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Clear the eligibility error flags
                formData.remove('_amountEligibilityError');
                formData.remove('_eligibleAmount');
              },
              child: Text(
                'OK',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _processTransaction() {
    // Pause idle timer to prevent logout during transaction
    IdleTimerService().pauseIdleTimer(reason: 'Processing transaction');

    final transactionService = TransactionService();

    transactionService.processTransaction(
      serviceCode: widget.serviceCode,
      formData: formData,
      context: context,
      balanceEnquiryType: widget.balanceEnquiryType,
      statusCallback: (bool isLoading) {
        setState(() {
          isProcessing = isLoading;
        });
      },
      completedCallback: (Map<String, dynamic> response, bool success) {
        _handleTransactionResponse(response, success);
      },
      otpCallback: () async {
        // Show the unified OTP dialog and return the OTP
        return await _showUnifiedOtpDialog();
      },
    );
  }

  Future<String?> _showUnifiedOtpDialog() async {
    String? phoneNumber = await SharedPreferencesHelper.getMsisdn() ?? 'your phone';

    String transactionType = _getTransactionTypeForOtp();
    String? amount = formData['amt']?.toString();

    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return UnifiedOtpDialog(
          phoneNumber: phoneNumber,
          transactionType: transactionType,
          amount: amount,
          onOtpVerified:
          null, // Let the dialog just collect OTP, don't verify here
          onCancel: () {
            // UnifiedOtpDialog handles its own navigation pop
            // Just perform any cleanup if needed
          },
          onMaxAttemptsReached: () {
            // Handle max attempts reached - logout user completely
            _handleOtpMaxAttemptsReached();
          },
        );
      },
    );
  }

  /// Show OTP dialog again for retry with error message
  Future<void> _showOtpRetryDialog(String retryMessage) async {
    try {
      // Get phone number from SharedPreferencesHelper
      String phoneNumber = await SharedPreferencesHelper.getMsisdn() ?? 'your phone';

      // Show the OTP dialog again with retry message
      String? otp = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return UnifiedOtpDialog(
            phoneNumber: phoneNumber,
            transactionType: _getTransactionTypeForOtp(),
            amount: formData['amt']?.toString(),
            onOtpVerified: null, // Let dialog just collect OTP
            initialErrorMessage: retryMessage, // Show retry message immediately
            onMaxAttemptsReached: () {
              // Handle max attempts reached - logout user completely
              _handleOtpMaxAttemptsReached();
            },
          );
        },
      );

      if (otp != null && otp.isNotEmpty) {
        // User entered new OTP, submit transaction again with new OTP
        await _retryTransactionWithOtp(otp);
      } else {
        // User cancelled OTP dialog, stay on current form
        AppLogger.info('User cancelled OTP retry dialog');
      }
    } catch (e) {
      AppLogger.error('Error showing OTP retry dialog: $e');
    }
  }

  /// Handle max OTP attempts reached - logout user completely
  void _handleOtpMaxAttemptsReached() async {
    try {
      // Get phone number for account lockout
      String? phoneNumber = await SharedPreferencesHelper.getMsisdn();

      if (phoneNumber != null) {
        // Trigger account lockout through AuthService
        await _authService.handleTransactionOtpError(phoneNumber, 'INVALID');

        // Show account locked dialog and logout
        ModernDialogs.showError(
          context: context,
          title: 'Account Locked',
          message: 'Maximum OTP attempts reached. Please try again later.',
          onPressed: () {
            Navigator.pop(context); // Close the error dialog
            _logoutAndNavigateToLogin(); // Logout and go to login screen
          },
        );
      } else {
        // Fallback - just logout
        _logoutAndNavigateToLogin();
      }
    } catch (e) {
      AppLogger.error('Error handling OTP max attempts: $e');
      _logoutAndNavigateToLogin(); // Fallback logout
    }
  }

  /// Retry transaction with new OTP
  Future<void> _retryTransactionWithOtp(String otp) async {
    try {
      // Pause idle timer again for retry attempt
      IdleTimerService().pauseIdleTimer(reason: 'Retrying transaction with OTP');

      // Create transaction service instance
      final transactionService = TransactionService();

      // Process transaction again with the new OTP using correct method signature
      await transactionService.processTransaction(
        serviceCode: widget.serviceCode,
        formData: formData,
        context: context,
        balanceEnquiryType: widget.balanceEnquiryType,
        statusCallback: (bool isLoading) {
          setState(() {
            isProcessing = isLoading;
          });
        },
        completedCallback: (Map<String, dynamic> response, bool success) {
          _handleTransactionResponse(response, success);
        },
        otpCallback: () async {
          // Return the new OTP directly
          return otp;
        },
      );
    } catch (e) {
      AppLogger.error('Error retrying transaction with OTP: $e');
      // Resume idle timer on error
      IdleTimerService().resumeIdleTimer(reason: 'Error during transaction retry');
      _showTransactionError(
          'An error occurred while retrying. Please try again.');
    }
  }

  String _getTransactionTypeForOtp() {
    if (_isWithdrawalTransaction()) {
      return 'withdrawal';
    } else if (_isInterAccountTransfer()) {
      return 'inter_account_transfer';
    } else if (_isBankTransferTransaction()) {
      return 'bank_transfer';
    } else if (_isPaybillTransaction()) {
      return 'paybill_payment';
    } else if (_isDepositTransaction()) {
      return 'deposit';
    } else if (_isUtilityBillTransaction()) {
      return 'utility_payment';
    } else if (_isB2BService()) {
      return 'b2b_payment';
    } else if (_isBalanceEnquiry()) {
      return 'balance_enquiry';
    } else if (_isStatementEnquiry()) {
      return 'statement_enquiry';
    }
    return 'transaction';
  }

  void _handleTransactionResponse(Map<String, dynamic> response, bool success) {
    // Resume idle timer now that transaction has completed
    IdleTimerService().resumeIdleTimer(reason: 'Transaction completed');

    if (success) {
      // Reset transaction PIN attempts on successful transaction
      _resetTransactionPinAttemptsOnSuccess();

      // Refresh accounts after successful transaction (except for enquiries and IDL)
      if (!_shouldSkipConfirmation() && widget.serviceCode != 'IDL') {
        _refreshAccountsAfterTransaction();
      }

      // Handle IDL (Digital Loans) success separately
      if (widget.serviceCode == 'IDL') {
        _showTransactionSuccess(response);
      } else if (_shouldSkipConfirmation()) {
        _showEnquiryResults(response);
      } else if (_isUtilityBillTransaction()) {
        _showUtilityBillOtpVerification(response);
      } else {
        _showTransactionSuccess(response);
      }
    } else {
      String errorMessage = _extractBackendErrorMessage(response);
      _handleTransactionError(errorMessage);
    }
  }

  /// Refresh accounts after successful transaction
  void _refreshAccountsAfterTransaction() {
    // Run account refresh in background without blocking UI
    AccountManager.refreshAccountsAfterTransaction().then((refreshedAccounts) {
      AppLogger.info(
          '✅ Accounts refreshed after transaction: ${refreshedAccounts.length} accounts');
    }).catchError((error) {
      AppLogger.error('❌ Failed to refresh accounts after transaction: $error');
      // Don't show error to user as this is a background operation
    });
  }

  void _showEnquiryResults(Map<String, dynamic> response) {
    Map<String, String> details = {};
    String title = _getEnquiryDisplayName();

    AppLogger.info('=== SHOWING ENHANCED ENQUIRY RESULTS ===');
    AppLogger.info('Message template config exists: ${messageTemplateConfig != null}');
    AppLogger.info('Success template exists: ${messageTemplateConfig?.successTemplate != null}');

    if (messageTemplateConfig?.successTemplate != null) {
      AppLogger.info('Using enhanced message template for enquiry results');
      details = messageTemplateConfig!.successTemplate!.generateSuccessDetails(
        response,
        formData,
        fieldAccountOptions: fieldAccountOptions,
      );
      title = messageTemplateConfig!.successTemplate!.title;
      AppLogger.info('Generated enquiry details from enhanced template: $details');
    } else {
      AppLogger.info('Falling back to legacy enquiry processing');
      if (_isBalanceEnquiry()) {
        _extractBalanceEnquiryDetails(response, details);
      } else if (_isStatementEnquiry()) {
        _extractStatementEnquiryDetails(response, details);
      } else {
        _extractGenericEnquiryDetails(response, details);
      }
    }

    final bool isMiniStatement = details.containsKey('__SPECIAL_TYPE__') &&
            details['__SPECIAL_TYPE__'] == 'MINI_STATEMENT' &&
            details.containsKey('__MINI_STATEMENT_DATA__') &&
            details['__MINI_STATEMENT_DATA__']!.isNotEmpty;

    if (!isMiniStatement && details.isEmpty) {
      AppLogger.info('Template generated no details, using fallback');
      _addFallbackEnquiryDetails(details, response);
    }

    // Check if this is a mini statement response
    if (isMiniStatement) {
      _showMiniStatementDialog(response, details, title);
    } else {
      _showDynamicSuccessDialog(title, details);
    }
  }

  void _showMiniStatementDialog(
      Map<String, dynamic> response,
      Map<String, String> details,
      String title,
      ) {
    AppLogger.info('=== SHOWING MINI STATEMENT DIALOG ===');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse the statement data
    String statementData = details['__MINI_STATEMENT_DATA__'] ?? '';
    AppLogger.info('Raw mini statement data: $statementData');
    List<Map<String, dynamic>> transactions = _parseStatementTransactions(statementData);

    // Get account information
    String accountName = _getSelectedAccountName();
    String accountNumber = formData['accNo']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildMiniStatementHeader(isDark, accountName),

                // Account Info Bar
                _buildMiniStatementAccountInfo(isDark, accountNumber, transactions.length),

                // Transactions List
                Expanded(
                  child: _buildMiniStatementTransactionsList(isDark, transactions),
                ),

                // Footer
                _buildMiniStatementFooter(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMiniStatementSuccess(
      Map<String, dynamic> response,
      Map<String, String> details,
      String title,
      ) {
    // Mini statement UI here...

    AppLogger.info('Showing mini statement success UI');

    // For now, fall back to regular result dialog
    details.remove('__SPECIAL_TYPE__');
    if (details.containsKey('__MINI_STATEMENT_DATA__')) {
      details.remove('__MINI_STATEMENT_DATA__');
    }

    _showResultDialog(title, details, true);
  }

  void _showTransactionSuccess(Map<String, dynamic> response) {
    Map<String, String> details = {};
    String title = 'Transaction Successful'; // Fallback title

    AppLogger.info('=== SHOWING ENHANCED TRANSACTION SUCCESS ===');
    AppLogger.info('Message template config exists: ${messageTemplateConfig != null}');
    AppLogger.info('Success template exists: ${messageTemplateConfig?.successTemplate != null}');

    // Use dynamic template from database if available
    if (messageTemplateConfig?.successTemplate != null) {
      AppLogger.info('USING ENHANCED MESSAGE TEMPLATE FROM DATABASE');

      Map<String, dynamic> successDisplayData = Map.from(formData);
      _resolveSelectFieldLabels(successDisplayData);

      // Swap eloanCode with eloanName for display
      if (successDisplayData.containsKey('eloanName') && successDisplayData['eloanName'] != null) {
        String readableName = successDisplayData['eloanName'];
        final loanKeys = ['eloanCode', 'eLoanCode', 'loanType', 'loanProduct', 'productName'];
        for (var key in loanKeys) {
          if (successDisplayData.containsKey(key)) {
            successDisplayData[key] = readableName;
            AppLogger.info('Success UI Override: Setting $key to "$readableName" for display');
          }
        }
      }

      details = messageTemplateConfig!.successTemplate!.generateSuccessDetails(
        response,
        successDisplayData,
        fieldAccountOptions: fieldAccountOptions,
      );

      title = messageTemplateConfig!.successTemplate!.title;

      AppLogger.info('📄 Template title: $title');
      AppLogger.info('📋 Generated details from template: $details');

      if (details.isEmpty) {
        AppLogger.info('Template generated no details, using enhanced fallback');
        details = _generateFallbackDetails(response);
      }
    } else {
      AppLogger.info('FALLING BACK TO LEGACY SUCCESS DETAILS');
      details = _generateFallbackDetails(response);
    }

    // Check if this is a mini statement for special handling
    if (details.containsKey('__SPECIAL_TYPE__') && details['__SPECIAL_TYPE__'] == 'MINI_STATEMENT') {
      _showMiniStatementSuccess(response, details, title);
    } else {
      _showDynamicSuccessDialog(title, details);
    }
  }

  void _showDynamicSuccessDialog(String title, Map<String, String> details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: ColorPalette.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Success Icon at the top center
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: ColorPalette.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: ColorPalette.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Scrollable details
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Transaction Details header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Transaction Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                              fontFamily: ClientThemeManager()
                                  .currentClientConfig
                                  .fontFamily,
                            ),
                          ),
                        ),

                        // Details list
                        ...details.entries
                            .map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    letterSpacing: 0.5,
                                    fontFamily: ClientThemeManager()
                                        .currentClientConfig
                                        .fontFamily,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: entry.key
                                        .toLowerCase()
                                        .contains('amount') ||
                                        entry.key.toLowerCase().contains('balance')
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: (entry.key.toLowerCase().contains('amount') ||
                                        entry.key.toLowerCase().contains('balance'))
                                        ? (isDark
                                        ? Colors.green[300]
                                        : Colors.green[700])
                                        : (isDark
                                        ? Colors.white
                                        : Colors.black87),
                                    fontFamily: ClientThemeManager()
                                        .currentClientConfig
                                        .fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                            .toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate back to the existing dashboard
                        _navigateToDashboard();

                        // Trigger account refresh in the background
                        // AccountManager.refreshAccountsAfterTransaction().then(
                        //         (refreshedAccounts) {
                        //       AppLogger.info(
                        //           '✅ Accounts refreshed after success dialog: ${refreshedAccounts.length} accounts'
                        //       );
                        //     }
                        // ).catchError((error) {
                        //   AppLogger.error(
                        //       '❌ Failed to refresh accounts after success dialog: $error'
                        //   );
                        // });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorPalette.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: ClientThemeManager()
                              .currentClientConfig
                              .fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, String> _generateFallbackDetails(Map<String, dynamic> response) {
    Map<String, String> details = {};

    AppLogger.info('Generating enhanced fallback details for service: ${widget.serviceCode}');

    // Extract values from form data and response
    if (formData.containsKey('accNo')) {
      String accountNo = formData['accNo'];
      // Try to resolve account name using fieldAccountOptions
      String accountDisplay = _resolveAccountName(accountNo);
      details['Destination Account'] = accountDisplay;
    }

    if (formData.containsKey('amt')) {
      details['Amount'] = 'KES ${formData['amt']}';
    }

    // Extract status from response
    if (response.containsKey('responseData') && response['responseData'] != null) {
      var responseData = response['responseData'];
      if (responseData.containsKey('msm')) {
        details['Status'] = responseData['msm'].toString();
      }
    }

    // If no status found in responseData, try header
    if (!details.containsKey('Status') &&
        response.containsKey('header') &&
        response['header'] != null) {
      var header = response['header'];
      if (header.containsKey('sd')) {
        details['Status'] = header['sd'].toString();
      } else if (header.containsKey('st')) {
        details['Status'] = header['st'].toString();
      }
    }

    // If still no status, add a generic success message
    if (!details.containsKey('Status')) {
      details['Status'] = 'Transaction completed successfully';
    }

    AppLogger.info('Trxn fallback details: $details');
    return details;
  }

  Map<String, String> _showFallbackConfirmationDialog () {
    Map<String, String> details = {};

    print("=== PREPARING FALLBACK TRANSACTION DETAILS ===");
    print("Service code: ${widget.serviceCode}");
    print("Form data: $formData");

    // Add basic transaction details
    if (formData.containsKey('accNo')) {
      String accountNo = formData['accNo'];
      Map<String, dynamic>? account = _findAccountByNumber(accountNo);
      if (account != null) {
        details['From Account'] = '${account['accountName']} - ${account['accountNo']}';
      } else {
        details['From Account'] = accountNo;
      }
    }

    if (formData.containsKey('amt')) {
      details['Amount'] = 'KES ${formData['amt']}';
    }

    // Service-specific details
    if (_isInterAccountTransfer() && formData.containsKey('otherAccNo')) {
      String destAccountNo = formData['otherAccNo'];
      Map<String, dynamic>? destAccount = _findAccountByNumber(destAccountNo);
      if (destAccount != null) {
        details['To Account'] = '${destAccount['accountName']} - ${destAccount['accountNo']}';
      } else {
        details['To Account'] = destAccountNo;
      }
    }

    if (_isWithdrawalTransaction() && formData.containsKey('description')) {
      details['Phone Number'] = formData['description'];
    }

    // Add service charge
    details['Service Charge'] = _getServiceCharges();

    return details;
  }

  String _getServiceCharges() {
    // Try to get service charges from form data
    if (formData.containsKey('serviceCharge')) {
      return 'KES ${formData['serviceCharge']}';
    }

    return '';
  }

  String _resolveAccountName(String accountNumber) {
    AppLogger.info('Resolving account name for: $accountNumber');

    // Look in fieldAccountOptions first
    for (String key in fieldAccountOptions.keys) {
      List<Map<String, dynamic>> accounts = fieldAccountOptions[key]!;
      for (Map<String, dynamic> account in accounts) {
        if (account['accountNo'] == accountNumber || account['id'] == accountNumber) {
          String accountName = account['accountName'] ?? account['name'] ?? '';
          if (accountName.isNotEmpty) {
            AppLogger.info('Found account name: $accountName');
            return '$accountName - $accountNumber';
          }
        }
      }
    }

    // Fallback to searching in allAccounts
    for (Map<String, dynamic> account in allAccounts) {
      if (account['accountNo'] == accountNumber || account['id'] == accountNumber) {
        String accountName = account['accountName'] ?? account['name'] ?? '';
        if (accountName.isNotEmpty) {
          AppLogger.info('Found account name in allAccounts: $accountName');
          return '$accountName - $accountNumber';
        }
      }
    }

    AppLogger.info('Account name not found, using account number only');
    return accountNumber;
  }

  Map<String, dynamic>? _findAccountByNumber(String accountNo) {
    print("=== FINDING ACCOUNT BY NUMBER ===");
    print("Looking for account: $accountNo");

    // Search in allAccounts
    for (Map<String, dynamic> account in allAccounts) {
      String? accNum = account['accountNo']?.toString() ?? account['id']?.toString();
      if (accNum == accountNo) {
        print("Found account: $account");
        return account;
      }
    }

    print("Account not found: $accountNo");
    return null;
  }

  bool _isBalanceEnquiry() {
    String code = widget.serviceCode.toUpperCase();
    return code.contains('BE') ||
        code.contains('BALANCE') ||
        code == 'SCBE' ||
        code == 'SBE' ||
        code == 'LB' ||
        code == 'NWDB' ||
        code == 'MS' ||  // Mini statement
        code == 'AS';    // Full statement
  }

  /// Handle transaction errors with PIN retry logic
  void _handleTransactionError(String errorMessage) async {
    String? phoneNumber = await SharedPreferencesHelper.getMsisdn();

    if (phoneNumber != null) {
      // Check if this is a PIN error first
      bool isPinError = _authService.isTransactionPinError(errorMessage);
      // Check if this is an OTP error
      bool isOtpError = _authService.isTransactionOtpError(errorMessage);

      if (isPinError) {
        // Use AuthService to handle PIN error with attempt tracking
        AuthResult result = await _authService.handleTransactionPinError(
            phoneNumber, errorMessage);

        if (result.type == AuthResultType.accountLocked) {
          // Account is locked - logout user immediately
          ModernDialogs.showError(
            context: context,
            title: 'Account Locked',
            message: result.message,
            onPressed: () {
              Navigator.pop(context); // Close the error dialog
              _logoutAndNavigateToLogin(); // Logout and go to login screen
            },
          );
        } else if (result.type == AuthResultType.error) {
          // PIN error with remaining attempts - enable retry mode and show retry message
          _enablePinRetryMode();
          _showTransactionError(result.message,
              shouldNavigateToDashboard: false);
        } else {
          // Unexpected result type
          _showTransactionError(errorMessage, shouldNavigateToDashboard: true);
        }
      } else if (isOtpError) {
        // Check if this is an immediate lockout from backend
        if (errorMessage.toLowerCase().contains('locked')) {
          // Backend says account is locked - logout immediately
          ModernDialogs.showError(
            context: context,
            title: 'Account Locked',
            message:
                'Your account has been locked due to multiple failed OTP attempts. Please try again later.',
            onPressed: () {
              Navigator.pop(context); // Close the error dialog
              _logoutAndNavigateToLogin(); // Logout and go to login screen
            },
          );
        } else {
          // Use AuthService to handle OTP error with attempt tracking
          AuthResult result = await _authService.handleTransactionOtpError(
              phoneNumber, errorMessage);

          if (result.type == AuthResultType.accountLocked) {
            // Account is locked - logout user immediately
            ModernDialogs.showError(
              context: context,
              title: 'Account Locked',
              message: result.message,
              onPressed: () {
                Navigator.pop(context); // Close the error dialog
                _logoutAndNavigateToLogin(); // Logout and go to login screen
              },
            );
          } else if (result.type == AuthResultType.error) {
            // OTP error with remaining attempts - show OTP dialog again for immediate retry
            AppLogger.info('OTP retry available: ${result.message}');
            _showOtpRetryDialog(result.message);
          } else {
            // Unexpected result type
            _showTransactionError(errorMessage,
                shouldNavigateToDashboard: true);
          }
        }
      } else {
        // Other error - show normal error handling
        // For IDL, stay on form to allow corrections without losing entered data
        bool shouldNavigate = widget.serviceCode != 'IDL';
        _showTransactionError(errorMessage, shouldNavigateToDashboard: shouldNavigate);
      }
    } else {
      // No phone number available - show normal error
      // For IDL, stay on form to allow corrections without losing entered data
      bool shouldNavigate = widget.serviceCode != 'IDL';
      _showTransactionError(errorMessage, shouldNavigateToDashboard: shouldNavigate);
    }
  }

  /// Show transaction error dialog
  void _showTransactionError(String errorMessage,
      {bool shouldNavigateToDashboard = true}) {
    ModernDialogs.showError(
      context: context,
      title: 'Transaction Failed',
      message: errorMessage,
      onPressed: () {
        Navigator.pop(context); // Close the error dialog
        if (shouldNavigateToDashboard) {
          _navigateToDashboard(); // Navigate to dashboard for locks and non-PIN errors
        }
        // For PIN retry errors, stay on the form to allow retry
      },
    );
  }

  /// Enable PIN retry mode without clearing the field
  void _enablePinRetryMode() {
    setState(() {
      _isInPinRetryMode = true; // Enable PIN retry mode
      // Don't clear the PIN field - let user see their previous attempt
    });
  }

  /// Reset transaction PIN attempts on successful transaction
  void _resetTransactionPinAttemptsOnSuccess() async {
    String? phoneNumber = await SharedPreferencesHelper.getMsisdn();
    if (phoneNumber != null) {
      await _authService.resetTransactionPinAttemptsOnSuccess(phoneNumber);
      await _authService.resetTransactionOtpAttemptsOnSuccess(phoneNumber);
    }
  }

  /// Handle PIN verification failure with retry logic
  Future<void> _handlePinVerificationFailure(AuthResult pinResult) async {
    if (pinResult.type == AuthResultType.accountLocked) {
      // Account is locked - show lock message and logout user
      ModernDialogs.showError(
        context: context,
        title: 'Account Locked',
        message: pinResult.message,
        onPressed: () {
          Navigator.pop(context); // Close the error dialog
          _logoutAndNavigateToLogin(); // Logout and go to login screen
        },
      );
    } else if (pinResult.type == AuthResultType.error) {
      // PIN error with remaining attempts - enable retry mode and show retry message
      _enablePinRetryMode();
      _showErrorSnackBar(pinResult.message);
      // Stay on the form to allow retry
    } else {
      // Unexpected result type
      _showErrorSnackBar(pinResult.message);
    }
  }

  /// Navigate back to the existing dashboard screen without recreating it.
  /// This avoids a full initState cascade (redundant tile/account API calls).
  void _navigateToDashboard() {
    // Pop all routes until we reach the root (DashboardScreen).
    // If the dashboard is not in the stack (unlikely), fall back to pushAndRemoveUntil.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(
            userName: '',
          ),
        ),
            (route) => false,
      );
    }
  }

  /// Logout user and navigate to login screen (for account lock scenarios)
  void _logoutAndNavigateToLogin() async {
    // Clear all stored user data using SharedPreferencesHelper
    await SharedPreferencesHelper.clearSharedPreferences();

    // Navigate to login screen and clear all routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  void _showResultDialog(
      String title, Map<String, String> details, bool isSuccess) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with title and icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ColorPalette.unselectedNavItemColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content with details
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Transaction Details header
                        // Container(
                        //   width: double.infinity,
                        //   padding: const EdgeInsets.only(bottom: 16),
                        //   child: Text(
                        //     'Transaction Details',
                        //     style: TextStyle(
                        //       fontSize: 16,
                        //       fontWeight: FontWeight.w600,
                        //       color: isDark ? Colors.white : Colors.black87,
                        //     ),
                        //   ),
                        // ),

                        // Details list with clean spacing
                        ...details.entries
                            .map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: entry.key
                                        .toLowerCase()
                                        .contains('balance')
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: entry.key
                                        .toLowerCase()
                                        .contains('balance')
                                        ? (isDark
                                        ? Colors.green[300]
                                        : Colors.green[700])
                                        : (isDark
                                        ? Colors.white
                                        : Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                            .toList(),

                        const SizedBox(height: 8),

                        // Done button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(
                                  context); // Go back to dashboard
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorPalette.secondary,
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
          ),
        ));
  }

  // Check if this is a statement enquiry
  bool _isStatementEnquiry() {
    Set<String> statementCodes = {'MS', 'AS'};
    return statementCodes.contains(widget.serviceCode) ||
        statementCodes.contains(widget.balanceEnquiryType);
  }

  // Check if this is a B2B service
  bool _isB2BService() {
    return b2bServiceCodes.contains(widget.serviceCode);
  }

  // Get display name for enquiry type
  String _getEnquiryDisplayName() {
    String serviceCode = widget.balanceEnquiryType ?? widget.serviceCode;

    switch (serviceCode) {
      case 'SCBE':
      case 'ASCB':
        return 'Share Balance Enquiry';
      case 'SBE':
        return 'Savings Balance Enquiry';
      case 'NWDB':
        return 'Investment Balance Enquiry';
      case 'LB':
      case 'ALB':
        return 'Loan Balance Enquiry';
      case 'ASB':
        return 'All Balances Enquiry';
      case 'ANB':
        return 'All Balances Enquiry';
      case 'MS':
        return 'Mini Statement';
      case 'AS':
        return 'Full Statement';
      default:
        return 'Balance Enquiry';
    }
  }

  // Extract balance enquiry details
  void _extractBalanceEnquiryDetails(
      Map<String, dynamic> response, Map<String, String> details) {
    if (response.containsKey('header')) {
      if (response['header'].containsKey('customerName')) {
        details['Account Holder'] = response['header']['customerName'];
      }

      // Special handling for ANB (All Balances) service
      if ((widget.serviceCode == 'ANB' || widget.balanceEnquiryType == 'ANB') &&
          response['header'].containsKey('st')) {
        String stField = response['header']['st'].toString();
        _parseAllBalancesFromHeader(stField, details);
      } else if (response['header'].containsKey('st')) {
        // For other balance enquiries, parse single balance from 'st' field
        String balanceStr = response['header']['st'].toString();
        if (balanceStr.isNotEmpty && balanceStr != '0') {
          double balance = _parseAmount(balanceStr);
          details['Available Balance'] =
          'KES ${NumberFormat("#,##0.00").format(balance)}';
        }
      }
    }

    if (response.containsKey('responseData')) {
      var responseData = response['responseData'];

      // Account information
      if (responseData.containsKey('accountType')) {
        details['Account Type'] = responseData['accountType'];
      }
      if (responseData.containsKey('accountName')) {
        details['Account Name'] = responseData['accountName'];
      }
      if (responseData.containsKey('accountNo')) {
        details['Account Number'] = responseData['accountNo'];
      }

      // Balance information from 'msm' field (main balance field)
      if (responseData.containsKey('msm')) {
        String balanceStr = responseData['msm'].toString();
        if (balanceStr.isNotEmpty && balanceStr != '0') {
          double balance = _parseAmount(balanceStr);
          details['Available Balance'] =
          'KES ${NumberFormat("#,##0.00").format(balance)}';
        }
      }

      // Alternative balance fields
      if (responseData.containsKey('balance')) {
        double balance = _parseAmount(responseData['balance']);
        details['Available Balance'] =
        'KES ${NumberFormat("#,##0.00").format(balance)}';
      }
      if (responseData.containsKey('ledgerBalance')) {
        double ledgerBalance = _parseAmount(responseData['ledgerBalance']);
        details['Ledger Balance'] =
            'KES ${NumberFormat("#,##0.00").format(ledgerBalance)}';
      }

      // Additional balance details
      if (responseData.containsKey('minBalance')) {
        double minBalance = _parseAmount(responseData['minBalance']);
        details['Minimum Balance'] =
        'KES ${NumberFormat("#,##0.00").format(minBalance)}';
      }
      if (responseData.containsKey('maxWithdrawable')) {
        double maxWithdrawable = _parseAmount(responseData['maxWithdrawable']);
        details['Max Withdrawable'] =
        'KES ${NumberFormat("#,##0.00").format(maxWithdrawable)}';
      }

      // Transaction charges
      if (responseData.containsKey('spotcashCommision') &&
          responseData['spotcashCommision'] != null) {
        double commission = _parseAmount(responseData['spotcashCommision']);
        if (commission > 0) {
          details['Service Charge'] =
          'KES ${NumberFormat("#,##0.00").format(commission)}';
        }
      }

      // Transaction ID
      if (responseData.containsKey('txnId')) {
        details['Transaction ID'] = responseData['txnId'];
      }
    }

    details['Enquiry Date'] =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  }

  // Extract statement enquiry details
  void _extractStatementEnquiryDetails(
      Map<String, dynamic> response, Map<String, String> details) {
    if (response.containsKey('header')) {
      if (response['header'].containsKey('customerName')) {
        details['Account Holder'] = response['header']['customerName'];
      }
    }

    if (response.containsKey('responseData')) {
      var responseData = response['responseData'];

      if (responseData.containsKey('accountName')) {
        details['Account Name'] = responseData['accountName'];
      }
      if (responseData.containsKey('accountNo')) {
        details['Account Number'] = responseData['accountNo'];
      }

      // Statement specific details
      if (responseData.containsKey('statementPeriod')) {
        details['Statement Period'] = responseData['statementPeriod'];
      }
      if (responseData.containsKey('emailAddress')) {
        details['Email Address'] = responseData['emailAddress'];
      }
    }

    details['Request Date'] =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  }

  // Extract generic enquiry details
  void _extractGenericEnquiryDetails(
      Map<String, dynamic> response, Map<String, String> details) {
    if (response.containsKey('responseData')) {
      var responseData = response['responseData'];
      responseData.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          details[_formatFieldName(key)] = value.toString();
        }
      });
    }
  }

  // Add fallback enquiry details
  void _addFallbackEnquiryDetails(
      Map<String, String> details, Map<String, dynamic> response) {
    if (response.containsKey('header') &&
        response['header'].containsKey('responseMessage')) {
      details['Result'] = response['header']['responseMessage'];
    } else if (response.containsKey('responseMessage')) {
      details['Result'] = response['responseMessage'];
    } else {
      details['Status'] = 'Enquiry completed successfully';
    }
  }

  // Parse amount from string/dynamic
  double _parseAmount(dynamic amount) {
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      try {
        return double.parse(amount.replaceAll(',', ''));
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Parse all balances from the header 'st' field for ANB service
  void _parseAllBalancesFromHeader(
      String stField, Map<String, String> details) {
    try {
      if (stField.isEmpty) {
        details['Balance Information'] = 'No balance data received';
        return;
      }

      // Use regex to find all balance patterns like "Ordinary Deposit Ksh: 1,000,000"
      RegExp balanceRegex =
          RegExp(r'([^,]+?)\s*Ksh:\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
      Iterable<RegExpMatch> matches = balanceRegex.allMatches(stField);

      int successfulParses = 0;

      for (RegExpMatch match in matches) {
        String accountType = match.group(1)?.trim() ?? '';
        String amountStr = match.group(2)?.trim() ?? '';

        if (accountType.isNotEmpty && amountStr.isNotEmpty) {
          // Clean up account type name
          String cleanedAccountType = _cleanAccountTypeName(accountType);

          // Parse and format amount
          double amount = _parseAmount(amountStr);
          String formattedAmount =
              'KES ${NumberFormat("#,##0.00").format(amount)}';

          details[cleanedAccountType] = formattedAmount;
          successfulParses++;
        }
      }

      if (successfulParses == 0) {
        details['Balance Information'] =
            stField; // Show the raw data if parsing fails
      }
    } catch (e) {
      details['Balance Information'] = 'Error parsing balance information';
    }
  }

  // Clean up account type names for better display
  String _cleanAccountTypeName(String accountType) {
    // Remove leading/trailing whitespace and normalize
    String cleaned = accountType.trim();

    // Handle common patterns
    if (cleaned.toLowerCase().contains('ordinary deposit')) {
      return 'Ordinary Deposit Balance';
    } else if (cleaned.toLowerCase().contains('savings')) {
      return 'Savings Account Balance';
    } else if (cleaned.toLowerCase().contains('share')) {
      return 'Share Capital Balance';
    } else if (cleaned.toLowerCase().contains('loan')) {
      return 'Loan Balance';
    }

    // Default: add "Balance" if not already present
    if (!cleaned.toLowerCase().contains('balance')) {
      cleaned += ' Balance';
    }

    return cleaned;
  }

  // Format field name for display
  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
        : '')
        .join(' ')
        .trim();
  }

  // Extract error message directly from backend response (sd field)
  String _extractBackendErrorMessage(Map<String, dynamic> response) {
    AppLogger.info('Extracting error message directly from backend response');
    AppLogger.info('Full response: $response');

    // PRIORITY 1: Check if this is a wrapped error response from TransactionService
    if (response.containsKey('error') &&
        response.containsKey('originalResponse')) {
      String errorMessage = response['error'].toString().trim();
      AppLogger.info('Found wrapped error message: "$errorMessage"');
      if (errorMessage.isNotEmpty) {
        AppLogger.info('✅ Using wrapped error message: "$errorMessage"');
        return errorMessage;
      }
      // If wrapped error is empty, try to extract from originalResponse
      if (response['originalResponse'] is Map<String, dynamic>) {
        AppLogger.info('Trying to extract from originalResponse...');
        return _extractBackendErrorMessage(
            response['originalResponse'] as Map<String, dynamic>);
      }
    }

    // NEW PRIORITY: Check for 'narration' field first (backend error messages)
    if (response.containsKey('narration') && response['narration'] != null) {
      String narration = response['narration'].toString().trim();
      AppLogger.info('Found narration field: "$narration"');
      if (narration.isNotEmpty) {
        AppLogger.info('✅ Using narration as error message: "$narration"');
        return narration;
      }
    }

    // PRIORITY 2: Check for direct message field (PIN verification responses)
    if (response.containsKey('message') && response['message'] != null) {
      String message = response['message'].toString().trim();
      AppLogger.info('Found direct message field: "$message"');
      if (message.isNotEmpty) {
        AppLogger.info('✅ Using direct message as error message: "$message"');
        return message;
      }
    }

    // PRIORITY 3: Check responseBody array for response_description
    if (response.containsKey('responseBody') &&
        response['responseBody'] is List) {
      List responseBody = response['responseBody'];
      AppLogger.info('Found responseBody array: $responseBody');
      if (responseBody.isNotEmpty && responseBody[0] is Map) {
        Map<String, dynamic> firstResponse = responseBody[0];
        if (firstResponse.containsKey('response_description')) {
          String responseDesc =
              firstResponse['response_description'].toString().trim();
          AppLogger.info('Found response_description: "$responseDesc"');
          if (responseDesc.isNotEmpty) {
            AppLogger.info(
                '✅ Using response_description as error message: "$responseDesc"');
            return responseDesc;
          }
        }
      }
    }

    // PRIORITY 4: Check eligibility responses (flat structure)
    if (response.containsKey('responseCode') &&
        response.containsKey('narration')) {
      String narration = response['narration'].toString().trim();
      AppLogger.info('Found check eligibility narration: "$narration"');
      if (narration.isNotEmpty) {
        // Clean up the narration message
        String cleanMessage = narration
            .replaceAll(' :', '')
            .replaceAll('\${PHONENUMBER}', 'your phone number')
            .replaceAll('There is no member with Mobile No. your phone number',
                'No member found with your phone number')
            .replaceAll('There is no member with your phone number',
                'No member found with your phone number')
            .trim();
        AppLogger.info(
            'Using cleaned narration as error message: "$cleanMessage"');
        return cleanMessage;
      }
    }

    // PRIORITY 5: Check for 'sd' field in header
    if (response.containsKey('header') && response['header'] is Map) {
      var header = response['header'] as Map<String, dynamic>;
      AppLogger.info('Header found: $header');

      if (header.containsKey('sd') && header['sd'] != null) {
        String sdMessage = header['sd'].toString().trim();
        AppLogger.info('Found sd field: "$sdMessage"');
        AppLogger.info('sd field isEmpty: ${sdMessage.isEmpty}');
        AppLogger.info('sd field toLowerCase: "${sdMessage.toLowerCase()}"');
        AppLogger.info(
            'sd field != success: ${sdMessage.toLowerCase() != 'success'}');
        if (sdMessage.isNotEmpty && sdMessage.toLowerCase() != 'success') {
          AppLogger.info('✅ Using sd field as error message: "$sdMessage"');
          return sdMessage;
        } else {
          AppLogger.info('❌ sd field rejected - empty or success');
        }
      } else {
        AppLogger.info('❌ No sd field found in header');
      }
    } else {
      AppLogger.info('❌ No header found in response');
    }

    // PRIORITY 6: Check for 'sd' field in responseData
    if (response.containsKey('responseData') &&
        response['responseData'] is Map) {
      var responseData = response['responseData'] as Map<String, dynamic>;
      AppLogger.info('ResponseData found: $responseData');

      if (responseData.containsKey('sd') && responseData['sd'] != null) {
        String sdMessage = responseData['sd'].toString().trim();
        AppLogger.info('Found sd field in responseData: "$sdMessage"');
        if (sdMessage.isNotEmpty && sdMessage.toLowerCase() != 'success') {
          AppLogger.info(
              'Using responseData sd field as error message: "$sdMessage"');
          return sdMessage;
        }
      }
    }

    // FALLBACK: Generic error message if no sd field found
    AppLogger.warning(
        'No error message fields found in response, using generic error message');
    return 'Transaction could not be completed. Please try again.';
  }

  // Check if this is a deposit transaction
  bool _isDepositTransaction() {
    return widget.serviceCode.contains('STK') ||
        widget.serviceCode == 'DEP' ||
        widget.serviceCode == 'DP' ||
        widget.serviceCode.startsWith('STK') ||
        (widget.tileResponse != null &&
            widget.tileResponse!['name'] == 'deposit');
  }

  // Check if this is a withdrawal transaction
  bool _isWithdrawalTransaction() {
    return widget.serviceCode == 'WD' ||
        (widget.tileResponse != null &&
            widget.tileResponse!['name'] == 'withdraw');
  }

  // Check if this is an inter-account transfer
  bool _isInterAccountTransfer() {
    return widget.serviceCode == 'IATOW' ||
        widget.serviceCode == 'IATOT' ||
        widget.serviceCode == 'IAT';
  }

  // Check if this is a utility bill transaction
  bool _isUtilityBillTransaction() {
    return widget.serviceCode == 'DSTV' ||
        widget.serviceCode == 'ZUKU' ||
        widget.serviceCode == 'STAR' ||
        widget.serviceCode == 'NWTR' ||
        widget.serviceCode == 'KPLCT';
  }

  // Check if this is an airtime transaction
  bool _isAirtimeTransaction() {
    return widget.serviceCode == 'AT';
  }

  // Check if this is a bank transfer transaction
  bool _isBankTransferTransaction() {
    return widget.serviceCode == 'PFTB' ||
        widget.serviceCode == 'FOSATOBANK' ||
        widget.serviceCode == 'F2B';
  }

  // Check if this is a paybill transaction
  bool _isPaybillTransaction() {
    return widget.serviceCode == 'B2P';
  }

  // Get utility bill display name
  String _getUtilityBillDisplayName() {
    switch (widget.serviceCode) {
      case 'DSTV':
        return 'DSTV';
      case 'ZUKU':
        return 'Zuku';
      case 'STAR':
        return 'Star Times';
      case 'NWTR':
        return 'Nairobi Water';
      default:
        return 'Utility Payment';
    }
  }

  /// Show OTP verification for utility bills
  void _showUtilityBillOtpVerification(Map<String, dynamic> response) async {
    // Get phone number for OTP
    String phoneNumber = await SharedPreferencesHelper.getMsisdn() ?? '';

    // Prepare transaction details for OTP screen
    Map<String, String> transactionDetails = {
      'account_type': _getSelectedAccountName(),
      'utility_account': formData[_getUtilityAccountKey()]?.toString() ?? '',
      'utility_type': _getUtilityBillDisplayName(),
      'amount': formData['amt']?.toString() ?? '0',
    };

    // Show OTP verification dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: OtpVerificationScreen(
          phoneNumber: phoneNumber,
          transactionType: '${_getUtilityBillDisplayName()} Payment',
          amount: formData['amt']?.toString() ?? '0',
          transactionDetails: transactionDetails,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // OTP verified successfully, show receipt
        _showUtilityBillTransactionReceipt();
      }
      // If result is null or false, user cancelled or OTP failed
      // Just close the dialog and return to form
    });
  }

  /// Get selected account name for transaction details
  String _getSelectedAccountName() {
    if (formData.containsKey('accNo') && allAccounts.isNotEmpty) {
      var selectedAccount = allAccounts.firstWhere(
            (account) => account['accountNo'] == formData['accNo'],
        orElse: () => allAccounts.first,
      );
      return selectedAccount['accountName'] ?? 'Account';
    } else if (allAccounts.isNotEmpty) {
      return allAccounts.first['accountName'] ?? 'Account';
    }
    return 'Account';
  }

  /// Show utility bill transaction receipt after successful OTP verification
  void _showUtilityBillTransactionReceipt() {
    String transactionType = '${_getUtilityBillDisplayName()} Payment';
    String amount = formData['amt']?.toString() ?? '0';
    String accountName = _getSelectedAccountName();
    String utilityAccount = formData[_getUtilityAccountKey()]?.toString() ?? '';

    Map<String, dynamic> receiptData = {
      'Transaction ID': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      'Transaction Type': transactionType,
      'Date & Time': DateTime.now().toString().substring(0, 19),
      'Amount': amount,
      'Description': _getUtilityBillTransactionDescription(
          transactionType, accountName, utilityAccount),
      'From Account': accountName,
      'Account Number': _getSelectedAccountNumber(),
      'Paying to': utilityAccount,
      'Utility': _getUtilityBillDisplayName(),
      'Status': 'Successful',
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionReceiptScreen(
          receiptData: receiptData,
          serviceCode: widget.serviceCode,
        ),
      ),
    );
  }

  /// Refresh destination accounts for inter-account transfers (IATOW, IATOT, IAT) when source account changes
  void _refreshDestinationAccountsForInterAccountTransfer() {
    try {
      // Find the otherAccNo field in the journeys
      for (var journey in journeys) {
        _refreshDestinationInFieldGroup(journey.fieldGroup);
      }
    } catch (e) {
      AppLogger.error('Error refreshing destination accounts for inter-account transfer: $e');
    }
  }

  /// Helper to recursively search and refresh otherAccNo field
  void _refreshDestinationInFieldGroup(List<FormFieldModel> fieldGroup) {
    for (var field in fieldGroup) {
      // Check nested field groups
      if (field.fieldGroup != null && field.fieldGroup!.isNotEmpty) {
        _refreshDestinationInFieldGroup(field.fieldGroup!);
      }
      if (field.fieldArray != null && field.fieldArray!.isNotEmpty) {
        _refreshDestinationInFieldGroup(field.fieldArray!);
      }

      // Found the otherAccNo field, re-filter it
      if (field.key == 'otherAccNo' &&
          (field.responseType == 'ACCOUNTS' ||
           field.responseType?.contains('ACCOUNTS') == true)) {

        AppLogger.info('Found otherAccNo field, re-filtering destination accounts for inter-account transfer');

        // Apply the same filtering logic as in _processAccountField
        Map<String, dynamic> fieldData = {
          'defaultValues': field.defaultValues,
          'responseType': field.responseType,
          'filterExpression': 'exclude:model.accNo',
          'currentFormData': formData,
        };

        List<Map<String, dynamic>> filteredAccounts =
            AccountFilteringService.filterAccountsForField(
          allAccounts,
          fieldData,
        );

        List<Map<String, dynamic>> options =
            AccountFilteringService.createAccountOptions(filteredAccounts);
        field.templateOptions['options'] = options;

        // Store the options (not raw accounts) so account name resolution works correctly
        fieldAccountOptions[field.key] = options;

        AppLogger.info(
            'Refreshed destination accounts: ${filteredAccounts.length} accounts available (excluding source account)');
      }
    }
  }

  /// Get selected account number
  String _getSelectedAccountNumber() {
    if (formData.containsKey('accNo') && allAccounts.isNotEmpty) {
      var selectedAccount = allAccounts.firstWhere(
            (account) => account['accountNo'] == formData['accNo'],
        orElse: () => allAccounts.first,
      );
      return selectedAccount['accountNo'] ?? '';
    } else if (allAccounts.isNotEmpty) {
      return allAccounts.first['accountNo'] ?? '';
    }
    return 'ACC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  /// Get utility bill transaction description
  String _getUtilityBillTransactionDescription(
      String type, String accountName, String utilityAccount) {
    return '$type from $accountName to account $utilityAccount';
  }

  // Get utility-specific account field key
  String _getUtilityAccountKey() {
    switch (widget.serviceCode) {
      case 'DSTV':
        return 'utilityAccountNumber';
      case 'ZUKU':
        return 'accountNumber';
      case 'STAR':
        return 'smartcardNumber';
      case 'NWTR':
        return 'accountNumber';
      case 'KPLCT':
        return 'accountNumber';
      default:
        return 'accountNumber';
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _amountFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Special handling for DL service
    if (widget.serviceCode == 'DL') {
      final theme = Theme.of(context);
      final String loanAppBarTitle = _loadingLoans
          ? "Loading..."
          : widget.loanTitle ?? 'Active Loans';

      return Scaffold(
        appBar: AppBar(
          backgroundColor: ColorPalette.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            loanAppBarTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
          centerTitle: true,
          toolbarHeight: 110.0,
        ),
        body: _buildLoanAccountsScreen(),
      );
    }

    final theme = Theme.of(context);
    String appBarTitle = isLoading
        ? "Loading..."
        : isProcessing
        ? "Processing..."
        : _getAppBarTitle();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorPalette.primary,
        centerTitle: true,
        title: Text(
          appBarTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: isProcessing ? null : () => Navigator.pop(context),
        ),
        toolbarHeight: 110.0,
      ),
      body: Container(
        color: ColorPalette.primary,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25.0),
            topRight: Radius.circular(25.0),
          ),
          child: Container(
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Stack(
                children: [
                  if (isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(ColorPalette.primary),
                      ),
                    )
                  else if (errorMessage != null && _isNoEligibleAccountsError)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: ColorPalette.warning,
                              size: 50,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No Eligible Accounts",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ColorPalette.warning,
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                text: "We couldn't find a valid account for this transaction. Please ",
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) => DashboardScreen(
                                              userName: '',
                                              initialTab: 2,
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                      child: Text(
                                        "contact your SACCO",
                                        style: TextStyle(
                                          color: ColorPalette.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: ColorPalette.primary,
                                          fontFamily: ClientThemeManager()
                                              .currentClientConfig
                                              .fontFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: " for assistance."),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                if (errorMessage != null &&
                                    errorMessage!.contains('Session expired')) {
                                  AppLogger.info(
                                      'Attempting token refresh before retry due to session expiry');
                                  try {
                                    bool refreshSuccess =
                                    await TokenRefreshService.instance
                                        .forceRefreshToken();
                                    if (refreshSuccess) {
                                      AppLogger.info(
                                          'Token refreshed successfully before retry');
                                    } else {
                                      AppLogger.warning(
                                          'Token refresh failed before retry');
                                    }
                                  } catch (e) {
                                    AppLogger.error(
                                        'Error refreshing token before retry: $e');
                                  }
                                }
                                _fetchServiceJourney();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorPalette.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              child: Text(
                                "Try Again",
                                style: TextStyle(
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ColorPalette.secondary,
                                side: BorderSide(color: ColorPalette.primary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              child: Text(
                                "Go Back",
                                style: TextStyle(
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: ColorPalette.warning.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_off_rounded,
                                color: ColorPalette.warning,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Service Unavailable",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ColorPalette.warning,
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "We couldn't load this service right now. Please try again shortly.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                text: "If the issue persists, please ",
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) => DashboardScreen(
                                              userName: '',
                                              initialTab: 2,
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                      child: Text(
                                        "contact your SACCO",
                                        style: TextStyle(
                                          color: ColorPalette.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: ColorPalette.primary,
                                          fontFamily: ClientThemeManager()
                                              .currentClientConfig
                                              .fontFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: " for assistance."),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                if (errorMessage != null &&
                                    errorMessage!.contains('Session expired')) {
                                  AppLogger.info(
                                      'Attempting token refresh before retry due to session expiry');
                                  try {
                                    bool refreshSuccess =
                                    await TokenRefreshService.instance
                                        .forceRefreshToken();
                                    if (refreshSuccess) {
                                      AppLogger.info(
                                          'Token refreshed successfully before retry');
                                    } else {
                                      AppLogger.warning(
                                          'Token refresh failed before retry');
                                    }
                                  } catch (e) {
                                    AppLogger.error(
                                        'Error refreshing token before retry: $e');
                                  }
                                }
                                _fetchServiceJourney();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorPalette.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              child: Text(
                                "Try Again",
                                style: TextStyle(
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ColorPalette.secondary,
                                side: BorderSide(color: ColorPalette.primary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              child: Text(
                                "Go Back",
                                style: TextStyle(
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isProcessing)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  ColorPalette.primary),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Processing Transaction...',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (journeys.any((j) => j.isTabbed))
                      Positioned.fill(
                        child: _buildTabbedJourney(),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildFormContent(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildStepNavigationButtons(),
                          ],
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

  Widget _buildMiniStatementHeader(bool isDark, String accountName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorPalette.secondary,
            ColorPalette.secondary.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Success Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: ColorPalette.secondary,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Mini Statement',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Account Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              accountName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMiniStatementAccountInfo(bool isDark, String accountNumber, int transactionCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Account Number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT NUMBER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.5,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accountNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          // Transaction Count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TRANSACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$transactionCount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.secondary,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatementTransactionsList(bool isDark, List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Transactions Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no recent transactions for this account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildMiniStatementTransactionItem(isDark, transaction);
      },
    );
  }

  Widget _buildMiniStatementTransactionItem(bool isDark, Map<String, dynamic> transaction) {
    final isDebit = transaction['type'] == 'debit';
    final amount = transaction['amount'];
    final date = transaction['date'];
    final reference = (transaction['reference'] ?? '').toString().trim();
    final narration = (transaction['narration'] ?? '').toString().trim();
    final subtitle = reference.isNotEmpty ? reference : narration;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Transaction Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isDebit ? Colors.red : Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDebit ? Icons.arrow_upward : Icons.arrow_downward,
              color: isDebit ? Colors.red[700] : Colors.green[700],
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                // Reference or narration
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDebit ? '-' : '+'}KES ${_formatAmount(amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDebit ? Colors.red[700] : Colors.green[700],
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatementFooter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to dashboard
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorPalette.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Done',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseStatementTransactions(String statementText) {
    final List<Map<String, dynamic>> transactions = [];

    try {
      AppLogger.info('Parsing statement text: $statementText');

      String cleaned = statementText.trim();

      cleaned = cleaned.replaceAll(RegExp(r'^[\|"]+'), '');


      cleaned = cleaned.replaceAll('"', '');

      // Normalize \n| and \n into | so we have a consistent single delimiter
      cleaned = cleaned.replaceAll('\n|', '|');
      cleaned = cleaned.replaceAll('\n', '|');

      AppLogger.info('Cleaned statement text: $cleaned');
      final lines = cleaned
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Pattern A: expects MM/DD/YY or DD/MM/YY followed by reference and amount with KES
      final RegExp patternA = RegExp(
        r'(\d{1,2}/\d{1,2}/\d{2,4})\s+(\d+)\s+KES:([-+]?\d+(?:,\d{3})*(?:\.\d+)?)',
      );

      // Pattern B: expects MM/DD/YY or DD/MM/YY followed by description and amount with KES
      final RegExp patternB = RegExp(
        r'^(\d{1,2}/\d{1,2}/\d{2,4})\s*:\s*(.+?)\s*:\s*([-+]?\d+(?:,\d{3})*(?:\.\d+)?)$',
      );

      // Pattern C: expects YYYY-MM-DD followed by description and amount with KES
      final RegExp patternC = RegExp(
        r'(\d{4}-\d{2}-\d{2})\s+(.+?)\s+KES\s+([-+]?\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*$',
      );

      final RegExp patternD = RegExp(
        r'^(\d{1,2}/\d{1,2}/\d{2,4})\s+(.+?)\s+([-+]?\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      );

      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;

        Match? matchA = patternA.firstMatch(line);
        if (matchA != null) {
          final date = matchA.group(1) ?? '';
          final reference = matchA.group(2) ?? '';
          final amountStr = matchA.group(3) ?? '0';

          final amount =
              double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;

          transactions.add({
            'date': _formatStatementDate(date),
            'reference': reference,
            'narration': '',
            'amount': amount.abs(),
            'type': amount < 0 ? 'debit' : 'credit',
          });

          continue;
        }

        Match? matchB = patternB.firstMatch(line);
        if (matchB != null) {
          final date = matchB.group(1) ?? '';
          final narration = (matchB.group(2) ?? '').trim();
          final amountStr = matchB.group(3) ?? '0';

          final amount =
              double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;

          transactions.add({
            'date': _formatStatementDate(date),
            'reference': '', // no msisdn/account in this format
            'narration': narration,
            'amount': amount.abs(),
            'type': amount < 0 ? 'debit' : 'credit',
          });

          continue;
        }

        Match? matchC = patternC.firstMatch(line);
        if (matchC != null) {
          final date = matchC.group(1) ?? '';
          final narration = (matchC.group(2) ?? '').trim();
          final amountStr = matchC.group(3) ?? '0';
          final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
          AppLogger.info('Pattern C matched: date=$date narration=$narration amount=$amount');
          transactions.add({
            'date': _formatStatementDate(date),
            'reference': '',
            'narration': narration,
            'amount': amount.abs(),
            'type': amount < 0 ? 'debit' : 'credit',
          });
          continue;
        }

        Match? matchD = patternD.firstMatch(line);
        if (matchD != null) {
          final date = matchD.group(1) ?? '';
          final narration = (matchD.group(2) ?? '').trim();
          final amountStr = matchD.group(3) ?? '0';
          final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
          transactions.add({
            'date': _formatStatementDate(date),
            'reference': '',
            'narration': narration,
            'amount': amount.abs(),
            'type': amount < 0 ? 'debit' : 'credit',
          });

          continue;
        }

        AppLogger.info('Unparsed statement line: $line');
      }

      // Sort by actual DateTime instead of string
      transactions.sort((a, b) {
        DateTime da = _tryParseFormattedDate(a['date'] ?? '') ?? DateTime(1900);
        DateTime db = _tryParseFormattedDate(b['date'] ?? '') ?? DateTime(1900);
        return db.compareTo(da); // latest first
      });

      AppLogger.info('Parsed ${transactions.length} transactions');
    } catch (e) {
      AppLogger.error('Error parsing transactions: $e');
    }

    return transactions;
  }

  DateTime? _tryParseFormattedDate(String date) {
    try {
      return DateFormat('MMM dd, yyyy').parse(date);
    } catch (_) {
      return null;
    }
  }


  /// Format date from statement format
  String _formatStatementDate(String date) {
    // Detect the separator used
    String separator = date.contains('/') ? '/' : '-';

    // Normalize 2-digit year to 4-digit before parsing
    // e.g. 20/3/26 → 20/3/2026 or 20-3-26 → 20-3-2026
    String normalizedDate = date.replaceAllMapped(
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2})$'),
          (match) => '${match[1]}$separator${match[2]}$separator${int.parse(match[3]!) + 2000}',
    );

    const List<String> formats = [
      'yyyy-MM-dd',   // 2026-03-20  (Year-Month-Day)
      'dd-MM-yyyy',   // 20-03-2026  (Day-Month-Year)
      'MM-dd-yyyy',   // 03-20-2026  (Month-Day-Year)
      'yyyy/MM/dd',   // 2026/03/20  (Year-Month-Day)
      'dd/MM/yyyy',   // 20/03/2026  (Day-Month-Year)
      'MM/dd/yyyy',   // 03/20/2026  (Month-Day-Year)
    ];

    for (String format in formats) {
      try {
        final DateTime parsed = DateFormat(format).parseStrict(normalizedDate);
        return DateFormat('MMM dd, yyyy').format(parsed);
      } catch (_) {
        continue;
      }
    }

    AppLogger.error('Unrecognized date format: $date');
    return date;
  }

  /// Format amount with proper decimal places
  String _formatAmount(double amount) {
    return NumberFormat("#,##0.00").format(amount);
  }

  Widget _buildLoanAccountItem(Map<String, dynamic> account, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String accountName = account['accountName']?.toString() ?? 'Loan Account';
    String accountNumber = account['accountNo']?.toString() ?? 'N/A';
    String balance = account['balance']?.toString() ?? '0.00';
    String currency = account['currency']?.toString() ?? 'KES';

    double balanceAmount = double.tryParse(balance.replaceAll(',', '')) ?? 0.0;
    String formattedBalance = NumberFormat("#,##0.00").format(balanceAmount.abs());

    // String status = balanceAmount > 0
    //     ? 'Outstanding'
    //     : balanceAmount < 0
    //     ? 'Overpaid'
    //     : 'Cleared';
    Color statusColor = _getBalanceColor(balance);
    IconData statusIcon = balanceAmount > 0
        ? Icons.pending_actions
        : balanceAmount < 0
        ? Icons.check_circle
        : Icons.done_all;

    // Is THIS card the expanded one?
    final bool isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.grey[850]!, Colors.grey[900]!]
              : [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: ColorPalette.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? -1 : index; // toggle
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ────── HEADER ROW ──────
                  Row(
                    children: [
                      // Loan Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorPalette.primary,
                              ColorPalette.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Account Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accountName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: ClientThemeManager()
                                    .currentClientConfig
                                    .fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.tag,
                                    size: 12,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600]),
                                const SizedBox(width: 3),
                                Text(
                                  accountNumber,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontFamily: ClientThemeManager()
                                        .currentClientConfig
                                        .fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      // Container(
                      //   padding:
                      //   const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      //   decoration: BoxDecoration(
                      //     color: statusColor.withOpacity(0.1),
                      //     borderRadius: BorderRadius.circular(16),
                      //     border: Border.all(
                      //         color: statusColor.withOpacity(0.3), width: 1),
                      //   ),
                      //   child: Row(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       Icon(statusIcon, size: 12, color: statusColor),
                      //       const SizedBox(width: 3),
                      //       Text(
                      //         status,
                      //         style: TextStyle(
                      //           fontSize: 10,
                      //           fontWeight: FontWeight.w600,
                      //           color: statusColor,
                      //           fontFamily: ClientThemeManager()
                      //               .currentClientConfig
                      //               .fontFamily,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ────── DIVIDER ──────
                  Container(
                    height: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),

                  const SizedBox(height: 12),

                  // ────── BALANCE SECTION ──────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outstanding balance',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontFamily: ClientThemeManager()
                                  .currentClientConfig
                                  .fontFamily,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                currency,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formattedBalance,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  fontFamily: ClientThemeManager()
                                      .currentClientConfig
                                      .fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Arrow icon (rotates when expanded)
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: ColorPalette.secondary,
                        ),
                      ),
                    ],
                  ),

                  // ────── EXPANDED CONTENT (Repay button) ──────
                  if (isExpanded) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to Form Journey Screen with loan account prepopulation
                          // Just like clicking the Repay Loan dashboard tile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormJourneyScreen(
                                serviceCode: 'STKLOANS',
                                preSelectedAccount: account,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorPalette.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: Text(
                          'Repay Loan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: ClientThemeManager()
                                .currentClientConfig
                                .fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBalanceColor(String balance) {
    // Remove commas before parsing
    final amount = double.tryParse(balance.replaceAll(',', '')) ?? 0;
    if (amount > 0) {
      return Colors.orange[700]!;
    } else if (amount < 0) {
      return Colors.green[600]!;
    } else {
      return Colors.blue[600]!;
    }
  }

  Widget _buildLoanAccountsScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loadingLoans) {
      return Container(
        color: ColorPalette.primary,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25.0),
            topRight: Radius.circular(25.0),
          ),
          child: Container(
            color: theme.colorScheme.surface,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ColorPalette.primary),
              ),
            ),
          ),
        ),
      );
    }

    if (_loanError != null) {
      return Container(
        color: ColorPalette.primary,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25.0),
            topRight: Radius.circular(25.0),
          ),
          child: Container(
            color: theme.colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_off,
                      color: ColorPalette.primary,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${widget.loanTitle ?? 'Active Loans'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ColorPalette.primary,
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loanError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.7),
                        fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorPalette.primary,
            ColorPalette.primary.withOpacity(0.85),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.loanTitle ?? 'Active Loans',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_loanAccounts.length} Loan${_loanAccounts.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loans List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                itemCount: _loanAccounts.length,
                itemBuilder: (context, index) {
                  final account = _loanAccounts[index];
                  return _buildLoanAccountItem(account, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerInfoBlink() {
    if (_infoBlinking) return;
    setState(() => _infoBlinking = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _infoBlinking = false);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _infoBlinking = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _infoBlinking = false);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _infoBlinking = true);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _infoBlinking = false);
            });
          });
        });
      });
    });
  }

  Widget _buildCarouselDepositInfoCard(bool isDark) {
    final palette = ClientThemeManager().colors;
    final accountName = widget.preSelectedAccount?['accountName']?.toString() ?? 'selected account';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Icon(
                    Icons.info_outline_rounded,
                    color: palette.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Locked Deposit',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : palette.textPrimary,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You initiated this deposit directly from your "$accountName" account card. '
                    'The deposit type and destination account have been pre-selected to match that account.\n\n'
                    'To deposit to a different account or to another member, '
                    'please use the Deposit option from the services menu instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : palette.textSecondary,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _infoBlinking
                ? (isDark ? Colors.white.withValues(alpha: 0.2) : palette.primary.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: palette.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Why is deposit type and destination account locked?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.primary,
                    fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    decoration: TextDecoration.underline,
                    decorationColor: palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Initialize TabController for tabbed journeys (e.g., for ASL)
  void _initializeTabController() {
    final tabbedJourney = journeys.where((j) => j.isTabbed).firstOrNull;
    if (tabbedJourney == null) return;

    // Filter visible tabs based on hideExpression
    _visibleTabs = tabbedJourney.tabs.where((tab) => !tab.shouldHide(formData)).toList();

    if (_visibleTabs.isEmpty) return;

    _tabController?.dispose();
    _tabController = TabController(length: _visibleTabs.length, vsync: this);

    AppLogger.info('TabController initialized with ${_visibleTabs.length} visible tabs: '
        '${_visibleTabs.map((t) => t.templateOptions['label']).toList()}');
  }

  /// Map icon name string from JSON config to Flutter IconData
  IconData _getTabIconData(String? iconName) {
    switch (iconName) {
      case 'check_circle_outline':
        return Icons.check_circle_outline;
      case 'description':
        return Icons.description;
      case 'people_outline':
        return Icons.people_outline;
      case 'security':
        return Icons.security;
      case 'folder_open':
        return Icons.folder_open;
      case 'rate_review':
        return Icons.rate_review;
      default:
        return Icons.circle_outlined;
    }
  }

  /// Build the tabbed journey UI for ASL secured loans
  Widget _buildTabbedJourney() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_tabController == null || _visibleTabs.isEmpty) {
      return Center(
        child: Text(
          'No tabs available.',
          style: TextStyle(
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: ColorPalette.primary,
            indicatorWeight: 3,
            labelColor: ColorPalette.primary,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
            ),
            tabAlignment: TabAlignment.start,
            tabs: _visibleTabs.map((tab) {
              final label = tab.templateOptions['label'] ?? tab.key;
              final iconName = tab.templateOptions['icon'] as String?;
              return Tab(
                icon: Icon(_getTabIconData(iconName), size: 20),
                text: label,
              );
            }).toList(),
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _visibleTabs.map((tab) {
              final label = tab.templateOptions['label'] ?? tab.key;
              final hasFields = tab.fieldGroup != null && tab.fieldGroup!.isNotEmpty;

              if (hasFields) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: DynamicForm(
                    fields: tab.fieldGroup!,
                    onChanged: _onFieldChanged,
                    formData: formData,
                    serviceCode: widget.serviceCode,
                    onEmailValidationErrorChanged: (bool hasErrors) {
                      setState(() {
                        _hasEmailValidationErrors = hasErrors;
                      });
                    },
                    onValidationChanged: (bool isValid) {
                      setState(() {
                        _hasFormValidationErrors = !isValid;
                      });
                    },
                    isDarkMode: isDark,
                  ),
                );
              }

              // Empty tab placeholder
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getTabIconData(tab.templateOptions['icon'] as String?),
                        size: 64,
                        color: ColorPalette.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ColorPalette.fontColor,
                          fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    if (journeys.isEmpty) {
      return Center(
        child: Text(
          'Service is currently unavailable.',
          style: TextStyle(
            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _getAllFormFields(),
    );
  }

  List<Widget> _getAllFormFields() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> allFields = [];
    final focusNodes = {
      'description': _phoneFocusNode,
      'amt': _amountFocusNode,
    };

    final validationMessages = {
      'description': _phoneValidationMessage,
    };

    final validationLoadingStates = {
      'description': _isValidatingPhone,
    };

    // Show info card for carousel deposits explaining locked fields
    if (_lockedFieldKeys.isNotEmpty && widget.transactionType == 'deposit' && widget.lockAccountSelection) {
      allFields.add(_buildCarouselDepositInfoCard(isDark));
    }

    for (var journey in journeys) {
      if (journey.type != 'stepper') {
        allFields.add(
          DynamicForm(
            fields: journey.fieldGroup,
            onChanged: _onFieldChanged,
            formData: formData,
            eloanCode: widget.eloanCode,
            serviceCode: widget.serviceCode,

            lockedFieldKeys: _lockedFieldKeys.isNotEmpty ? _lockedFieldKeys : null,
            onLockedFieldTapped: _lockedFieldKeys.isNotEmpty ? _triggerInfoBlink : null,
            onEmailValidationErrorChanged: (bool hasErrors) {
              setState(() {
                _hasEmailValidationErrors = hasErrors;
              });
            },
            onValidationChanged: (bool isValid) {
              setState(() {
                _hasFormValidationErrors = !isValid;
              });
            },
            focusNodes: focusNodes,
            validationMessages: validationMessages,
            validationLoadingStates: validationLoadingStates,
            isDarkMode: isDark,
            onContactPicked: (key, phoneNumber) {
              if (key == 'description') {
                _validatePhoneNumberOnBlur();
              }
            },
          ),
        );
        continue;
      }

      // NEW: Handle stepper journeys (multi-step) - render only current step
      List<FormFieldModel> steps = journey.steps;

      if (steps.isEmpty) {
        AppLogger.warning('Stepper journey has no steps');
        continue;
      }

      // Only render the current step
      if (_currentStepIndex < steps.length) {
        FormFieldModel currentStep = steps[_currentStepIndex];

        // Add step indicator only for multi-step journeys (IDL)
        if (steps.length > 1) {
          allFields.add(_buildStepIndicator(steps.length, _currentStepIndex));
        }

        // Add step label if present
        if (currentStep.templateOptions.containsKey('label') &&
            currentStep.templateOptions['label'] != null &&
            currentStep.templateOptions['label'].toString().isNotEmpty) {
          allFields.add(
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                currentStep.templateOptions['label'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ColorPalette.fontColor,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
            ),
          );
        }

        // Render current step's fields
        if (currentStep.fieldGroup != null && currentStep.fieldGroup!.isNotEmpty) {
          allFields.add(
            DynamicForm(
              fields: currentStep.fieldGroup!,
              onChanged: _onFieldChanged,
              formData: formData,
              eloanCode: widget.eloanCode,
              serviceCode: widget.serviceCode,
  
              lockedFieldKeys: _lockedFieldKeys.isNotEmpty ? _lockedFieldKeys : null,
              onLockedFieldTapped: _lockedFieldKeys.isNotEmpty ? _triggerInfoBlink : null,
              onEmailValidationErrorChanged: (bool hasErrors) {
                setState(() {
                  _hasEmailValidationErrors = hasErrors;
                });
              },
              onValidationChanged: (bool isValid) {
                setState(() {
                  _hasFormValidationErrors = !isValid;
                });
              },
              focusNodes: focusNodes,
              validationMessages: validationMessages,
              validationLoadingStates: validationLoadingStates,
              isDarkMode: isDark,
              onContactPicked: (key, phoneNumber) {
                if (key == 'description') {
                  _validatePhoneNumberOnBlur();
                }
              },
            ),
          );
        }

        // Add eligibility error message if present (for Screen 1)
        if (_eligibilityError != null && _currentStepIndex == 0) {
          allFields.add(
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _eligibilityError!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                          fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    return allFields;
  }

  /// Build step navigation buttons (Back, Next/Check Eligibility, Submit)
  Widget _buildStepNavigationButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Check if we're in a stepper journey
    FormJourneyModel? stepperJourney = journeys.firstWhere(
      (j) => j.isStepper,
      orElse: () => journeys.isNotEmpty ? journeys.first : FormJourneyModel(type: 'form', fieldGroup: []),
    );

    if (!stepperJourney.isStepper) {
      // Not a stepper, use default Continue button
      return ElevatedButton(
        onPressed: isProcessing ? null : _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: isProcessing ? Colors.grey[400] : ColorPalette.secondary,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ],
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                ),
              ),
      );
    }

    // Stepper journey - build step-specific buttons
    List<FormFieldModel> steps = stepperJourney.steps;

    if (_currentStepIndex >= steps.length) {
      return SizedBox.shrink();
    }

    FormFieldModel currentStep = steps[_currentStepIndex];
    Map<String, dynamic> buttonConfig = currentStep.buttonConfig;
    bool isLastStep = _currentStepIndex == steps.length - 1;

    // Validate form based on whether it's IDL (multi-step) or non-IDL (single-step)
    bool canProceed = true;
    bool isIDL = steps.length > 1; // IDL has multiple steps, non-IDL has single step

    if (isIDL && _currentStepIndex == 0) {
      // IDL-specific validation for Screen 1 (amt and repaymentPeriod)
      String amt = formData['amt']?.toString() ?? '';
      String repaymentPeriod = formData['repaymentPeriod']?.toString() ?? '';

      // Check if fields are filled
      if (amt.isEmpty || repaymentPeriod.isEmpty) {
        canProceed = false;
      } else {
        // Check if there are validation errors
        if (_hasFormValidationErrors) {
          canProceed = false;
        } else {
          // Validate amt against min/max constraints
          FormFieldModel? amtField = currentStep.fieldGroup?.firstWhere(
            (field) => field.key == 'amt',
            orElse: () => FormFieldModel(key: '', type: '', templateOptions: {}),
          );

          if (amtField != null && amtField.key == 'amt') {
            final double amtValue = _parseAmount(amt);
            final double? min = amtField.templateOptions['min'] != null
                ? _parseAmount(amtField.templateOptions['min'])
                : null;
            final double? max = amtField.templateOptions['max'] != null
                ? _parseAmount(amtField.templateOptions['max'])
                : null;

            if (min != null && amtValue < min) {
              canProceed = false;
            }

            if (max != null && amtValue > max) {
              canProceed = false;
            }
          }


          // Validate repaymentPeriod against min/max constraints
          FormFieldModel? periodField = currentStep.fieldGroup?.firstWhere(
            (field) => field.key == 'repaymentPeriod',
            orElse: () => FormFieldModel(key: '', type: '', templateOptions: {}),
          );

          if (periodField != null && periodField.key == 'repaymentPeriod') {
            final double periodValue = _parseAmount(repaymentPeriod);
            final double? min = periodField.templateOptions['min'] != null
                ? _parseAmount(periodField.templateOptions['min'])
                : null;
            final double? max = periodField.templateOptions['max'] != null
                ? _parseAmount(periodField.templateOptions['max'])
                : null;

            // Reject invalid or zero values
            if (periodValue <= 0) {
              canProceed = false;
            } else {
              if (min != null && periodValue < min) {
                canProceed = false;
              }
              if (max != null && periodValue > max) {
                canProceed = false;
              }
            }
          }

        }
      }
    } else if (!isIDL) {
      // Non-IDL validation: check for validation errors and required fields
      if (_hasFormValidationErrors) {
        canProceed = false;
      } else {
        // Validate required fields in current step
        List<String> missingFields = [];
        if (currentStep.fieldGroup != null) {
          canProceed = _recursiveValidate(currentStep.fieldGroup!, missingFields);
        }
      }
    }

    // Check if we're on Screen 2 (has back button)
    bool showBackButton = _currentStepIndex > 0 && (buttonConfig['showBackButton'] == true || _currentStepIndex > 0);

    if (showBackButton) {
      // Screen 2: Horizontal layout with Back and Submit
      return Row(
        children: [
          // Back button on the left
          Expanded(
            child: OutlinedButton(
              onPressed: _onStepBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: isDark ? Colors.white : ColorPalette.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, color: isDark ? Colors.white : ColorPalette.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    buttonConfig['backButtonLabel'],
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : ColorPalette.primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Submit button on the right
          Expanded(
            child: ElevatedButton(
              onPressed: (_isCheckingEligibility || isProcessing || !canProceed)
                  ? null
                  : () => _onStepAction(currentStep, isLastStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: (_isCheckingEligibility || isProcessing || !canProceed)
                    ? Colors.grey[400]
                    : ColorPalette.secondary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isCheckingEligibility
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Checking Eligibility...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                          ),
                        ),
                      ],
                    )
                  : isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          isLastStep
                              ? buttonConfig['submitButtonLabel']
                              : buttonConfig['nextButtonLabel'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                          ),
                        ),
            ),
          ),
        ],
      );
    } else {
      // Screen 1: Single button (Check Eligibility)
      return ElevatedButton(
        onPressed: (_isCheckingEligibility || isProcessing || !canProceed)
            ? null
            : () => _onStepAction(currentStep, isLastStep),
        style: ElevatedButton.styleFrom(
          backgroundColor: (_isCheckingEligibility || isProcessing || !canProceed)
              ? Colors.grey[400]
              : ColorPalette.secondary,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isCheckingEligibility
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Checking Eligibility...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
                ],
              )
            : isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                        ),
                      ),
                    ],
                  )
                : Text(
                    isLastStep
                        ? buttonConfig['submitButtonLabel']
                        : buttonConfig['nextButtonLabel'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: ClientThemeManager().currentClientConfig.fontFamily,
                    ),
                  ),
      );
    }
  }

  /// Handle step action (Next or Submit)
  Future<void> _onStepAction(FormFieldModel currentStep, bool isLastStep) async {
    String action = isLastStep
        ? currentStep.buttonConfig['submitButtonAction']
        : currentStep.buttonConfig['nextButtonAction'];

    if (action == 'checkEligibility') {
      // Screen 1: Check eligibility before navigating
      await _idlCheckEligibilityAndNavigate();
    } else if (action == 'navigate') {
      // Regular navigation to next step
      _navigateToNextStep();
    } else if (action == 'submit') {
      // Final submission
      _onContinue();
    }
  }

  /// Navigate back to previous step
  void _onStepBack() {
    setState(() {
      if (_currentStepIndex > 0) {
        _currentStepIndex--;
        _eligibilityError = null; // Clear any errors when going back
      }
    });
  }

  /// Navigate to next step
  void _navigateToNextStep() {
    FormJourneyModel? stepperJourney = journeys.firstWhere(
      (j) => j.isStepper,
      orElse: () => journeys.isNotEmpty ? journeys.first : FormJourneyModel(type: 'form', fieldGroup: []),
    );

    List<FormFieldModel> steps = stepperJourney.steps;

    setState(() {
      if (_currentStepIndex < steps.length - 1) {
        // Store current step data before navigating
        _stepFormData[_currentStepIndex] = Map.from(formData);
        _currentStepIndex++;
        _eligibilityError = null;
      }
    });
  }

  /// Check eligibility and navigate if successful
  Future<void> _idlCheckEligibilityAndNavigate() async {
    setState(() {
      _isCheckingEligibility = true;
      _eligibilityError = null;
    });

    try {
      String amount = formData['amt']?.toString() ?? '';
      String? repaymentPeriod = formData['repaymentPeriod']?.toString();
      String? eloanCode = widget.eloanCode;

      if (amount.isEmpty) {
        setState(() {
          _eligibilityError = 'Please enter loan amount';
          _isCheckingEligibility = false;
        });
        return;
      }

      if (repaymentPeriod == null || repaymentPeriod.isEmpty) {
        setState(() {
          _eligibilityError = 'Please select repayment period';
          _isCheckingEligibility = false;
        });
        return;
      }

      // Check if values haven't changed from last successful eligibility check
      bool valuesUnchanged = _lastCheckedAmount == amount &&
                              _lastCheckedPeriod == repaymentPeriod;
      bool hasEligibilityData = formData.containsKey('guarantorsCount') &&
                                 formData['guarantorsCount'] != null;

      if (valuesUnchanged && hasEligibilityData) {
        // Values unchanged - skip API call and navigate directly
        AppLogger.info('Eligibility data unchanged - skipping API call');
        setState(() {
          _isCheckingEligibility = false;
        });
        _navigateToNextStep();
        return;
      }

      // Step 1: Check eligibility - this provides maxEligibleAmount ONLY
      final result = await _digitalLoansService.checkEligibility(
        amount: amount,
        repaymentPeriod: repaymentPeriod,
        eloanCode: eloanCode,
      );

      AppLogger.info('IDL Eligibility Result: $result');

      String responseCode = result['responseCode'] ?? '';

      if (responseCode == '00') {
        // Extract maxEligibleAmount from checkEligibility
        // This is the ONLY value we use from eligibility response for displayField
        String eligibleAmount = '0';

        // Extract eligible amount from the 'amount' field in response
        // e.g., "Dear USER XYZ, you are Eligible up to 500,000"
        String amountField = result['amount']?.toString() ?? '';
        if (amountField.isNotEmpty) {
          RegExp regex = RegExp(r'[\d,]+(?:\.\d+)?');
          Iterable<Match> matches = regex.allMatches(amountField);
          if (matches.isNotEmpty) {
            // Get the last numeric match (usually the amount)
            eligibleAmount = matches.last.group(0) ?? '0';
          }
        }

        // Fallback: Try other fields if amount extraction failed
        if (eligibleAmount == '0') {
          if (result.containsKey('eligibleAmount')) {
            eligibleAmount = result['eligibleAmount']?.toString() ?? '0';
          } else if (result.containsKey('maxEligibleAmount')) {
            eligibleAmount = result['maxEligibleAmount']?.toString() ?? '0';
          }
        }

        AppLogger.info('Extracted maxEligibleAmount from eligibility response: $eligibleAmount');

        // Step 2: Fetch loan details - ALL displayField values come from this response
        // (except maxEligibleAmount which comes from eligibility response above)
        final loanDetailsResult = await _digitalLoansService.fetchLoanDetails(
          eloanCode: eloanCode!,
          amount: amount,
        );

        AppLogger.info('IDL FLD Loan Details Result: $loanDetailsResult');

        String fldResponseCode = loanDetailsResult['responseCode'] ?? '';

        if (fldResponseCode == '00') {
          int guarantorsCount = 0;
          if (loanDetailsResult.containsKey('guarantorRequired')) {
            guarantorsCount = int.tryParse(loanDetailsResult['guarantorRequired'].toString()) ?? 0;
          }

          AppLogger.info('FLD - guarantorRequired: $guarantorsCount');
          AppLogger.info('FLD response keys: ${loanDetailsResult.keys.toList()}');

          // Handle guarantor count changes (if re-checking eligibility)
          List<dynamic> existingGuarantors = formData['guarantors'] ?? [];
          if (existingGuarantors.length > guarantorsCount) {
            existingGuarantors = existingGuarantors.sublist(0, guarantorsCount);
          }

          _updateDisplayFieldWithFldResponse(loanDetailsResult, eligibleAmount, guarantorsCount);

          setState(() {
            formData['guarantorsCount'] = guarantorsCount;
            formData['eligibleAmount'] = eligibleAmount;
            formData['fldResponse'] = loanDetailsResult; // Store FLD response for reference
            formData['guarantors'] = existingGuarantors; // Preserve or initialize guarantors array
            _isCheckingEligibility = false;
            // Cache the checked values to avoid re-fetching when values unchanged
            _lastCheckedAmount = amount;
            _lastCheckedPeriod = repaymentPeriod;
          });

          // Navigate to next step
          _navigateToNextStep();
        } else {
          // FLD fetch failed
          String errorMsg = loanDetailsResult['narration'] ??
              loanDetailsResult['message'] ??
              'Failed to fetch loan details';

          setState(() {
            _eligibilityError = errorMsg;
            _isCheckingEligibility = false;
          });
        }
      } else {
        // Eligibility failed
        String errorMsg = result['narration'] ??
            result['message'] ??
            'Amount is not eligible';

        setState(() {
          _eligibilityError = errorMsg;
          _isCheckingEligibility = false;
        });
      }
    } catch (e) {
      AppLogger.error('Eligibility check error: $e');
      setState(() {
        _eligibilityError = 'Failed to check eligibility. Please try again.';
        _isCheckingEligibility = false;
      });
    }
  }

  /// Build step indicator widget for visual progress
  Widget _buildStepIndicator(int totalSteps, int currentStep) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: List.generate(totalSteps, (index) {
          bool isActive = index == currentStep;
          bool isCompleted = index < currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? ColorPalette.primary
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < totalSteps - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Show error message via SnackBar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}