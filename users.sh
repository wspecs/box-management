#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh

# If there aren't any mail users yet, create one.
if [ -z "`tools/mail.py user`" ]; then
  HOST=$(echo $PRIMARY_HOSTNAME | sed s/^box.//)
  EMAIL_ADDR=wspecs@$HOST
  USER_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
  add_config USER_SECRET=$USER_SECRET $HOME/.wspecsbox.conf
  echo
  echo "Creating a new administrative mail account for $EMAIL_ADDR."
  echo

  # Create the user's mail account. This will ask for a password if none was given above.
  tools/mail.py user add $EMAIL_ADDR ${USER_SECRET:-}

  # Make it an admin.
  hide_output tools/mail.py user make-admin $EMAIL_ADDR

  # Create an alias to which we'll direct all automatically-created administrative aliases.
  tools/mail.py alias add administrator@$PRIMARY_HOSTNAME $EMAIL_ADDR > /dev/null
fi

