#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh

# If there aren't any mail users yet, create one.
if [ -z "`tools/mail.py user`" ]; then
  # The outut of "tools/mail.py user" is a list of mail users. If there
  # aren't any yet, it'll be empty.

  # If we didn't ask for an email address at the start, do so now.
  if [ -z "${EMAIL_ADDR:-}" ]; then
    EMAIL_ADDR=wspecs@$PRIMARY_HOSTNAME
    USER_SECRET="$(openssl rand -base64 36 | tr -d "=+/" | cut -c1-32)"
    add_config WSPECS_USER_SECRET=$USER_SECRET ~/.wspecs.conf
    echo
    echo "Creating a new administrative mail account for $EMAIL_ADDR."
    echo
  fi

  # Create the user's mail account. This will ask for a password if none was given above.
  tools/mail.py user add $EMAIL_ADDR ${USER_SECRET:-}

  # Make it an admin.
  hide_output tools/mail.py user make-admin $EMAIL_ADDR

  # Create an alias to which we'll direct all automatically-created administrative aliases.
  tools/mail.py alias add administrator@$PRIMARY_HOSTNAME $EMAIL_ADDR > /dev/null
fi

