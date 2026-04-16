import logging
from typing import Optional

logger = logging.getLogger("firebase_service")

# Attempt to load firebase_admin
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    
    # Initialize if not already initialized
    try:
        firebase_admin.get_app()
    except ValueError:
        try:
            # We will use application default credentials.
            # If GOOGLE_APPLICATION_CREDENTIALS exists, it works natively.
            firebase_admin.initialize_app()
            logger.info("Firebase Admin initialized via application default credentials.")
        except Exception as e:
            logger.warning("Firebase initialization skipped (missing credentials): %s", e)
            
except ImportError:
    messaging = None
    logger.warning("firebase_admin package not installed. Push notifications disabled.")


def send_push_notification(fcm_token: str, title: str, body: str, data: Optional[dict] = None) -> bool:
    """
    Sends a push notification to a specific FCM token payload.
    Wrapped tightly in a generic EXCEPT guard to prevent scheduler crashes.
    """
    if not messaging:
        logger.warning("Cannot send FCM. library missing or not initialized.")
        return False
        
    if not fcm_token:
        logger.warning("FCM token missing. Cannot send push.")
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data or {},
            token=fcm_token,
        )
        response = messaging.send(message)
        logger.info("FCM push successful to %s: %s", fcm_token[:8], response)
        return True
    except Exception as e:
        logger.error("Failed to execute FCM push to %s... -> %s", fcm_token[:8], e)
        return False
