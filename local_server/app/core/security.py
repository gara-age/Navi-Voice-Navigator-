PASSWORD_KO = "\uBE44\uBC00\uBC88\uD638"
OTP_KO = "\uC778\uC99D\uBC88\uD638"
ACCOUNT_KO = "\uACC4\uC88C"
LOGIN_KO = "\uB85C\uADF8\uC778"
PAYMENT_KO = "\uACB0\uC81C"

SENSITIVE_KEYWORDS = {
    "password",
    "otp",
    "account",
    "bank",
    "login",
    "payment",
    PASSWORD_KO,
    OTP_KO,
    ACCOUNT_KO,
    LOGIN_KO,
    PAYMENT_KO,
}

DANGEROUS_ACTION_KEYWORDS = {
    "transfer",
    "send money",
    "delete account",
    PASSWORD_KO,
    OTP_KO,
}


def contains_sensitive_text(text: str) -> bool:
    lowered = text.lower()
    return any(keyword.lower() in lowered for keyword in SENSITIVE_KEYWORDS)


def contains_dangerous_automation(text: str) -> bool:
    lowered = text.lower()
    return any(keyword.lower() in lowered for keyword in DANGEROUS_ACTION_KEYWORDS)
