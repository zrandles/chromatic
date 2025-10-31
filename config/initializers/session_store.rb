# SECURITY: Configure secure session settings
Rails.application.config.session_store :cookie_store,
  key: '_chromatic_session',
  secure: Rails.env.production?, # Use secure cookies in production (HTTPS only)
  httponly: true,                # Prevent JavaScript access to cookies
  same_site: :lax,               # CSRF protection
  expire_after: 24.hours         # Session timeout
