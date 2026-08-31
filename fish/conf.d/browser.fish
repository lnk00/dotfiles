# Default browser for CLI tools that shell out to $BROWSER
# (gh auth login, gcloud auth login, python webbrowser, cargo doc --open, ...).
# Set in conf.d (not config.fish) so it also applies to the login shell that
# starts jay -- every GUI app jay launches inherits it from there.
set -gx BROWSER glide-bin
