bool isEmail(String value) {
  final String trimmed = value.trim();
  return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(trimmed);
}

String? validatePhoneNumber(String? value) {
  final String? sanitized = value?.replaceAll(RegExp(r'[\s\-().]'), '');
  if (sanitized == null || sanitized.isEmpty) {
    return 'Saisissez votre numéro de téléphone';
  }
  if (!RegExp(r'^\+?\d{8,15}$').hasMatch(sanitized)) {
    return 'Numéro invalide (8 à 15 chiffres)';
  }
  return null;
}

String? validateEmail(String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return 'Saisissez votre adresse e-mail';
  }
  if (!isEmail(trimmed)) {
    return 'Adresse e-mail invalide';
  }
  return null;
}

String? validateIdentifier(String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return 'Saisissez votre téléphone ou e-mail';
  }
  return isEmail(trimmed)
      ? validateEmail(trimmed)
      : validatePhoneNumber(trimmed);
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Saisissez votre mot de passe';
  }
  if (value.length < 8) {
    return '8 caractères minimum';
  }
  return null;
}

String? validateFullName(String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return 'Nom complet requis';
  }
  if (!trimmed.contains(' ')) {
    return 'Saisissez votre nom et votre prénom';
  }
  return null;
}

String? validatePasswordConfirmation(String? password, String? confirmation) {
  if (confirmation == null || confirmation.isEmpty) {
    return 'Confirmez votre mot de passe';
  }
  if (confirmation != password) {
    return 'Les mots de passe ne correspondent pas';
  }
  return null;
}

String? validateTermsAccepted(bool? accepted) {
  if (accepted == null || !accepted) {
    return 'Vous devez accepter les conditions';
  }
  return null;
}
