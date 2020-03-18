#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh

# If there aren't any mail users yet, create one.
if [ -z "`tools/mail.py user`" ]; then
  HOST=$(echo $PRIMARY_HOSTNAME | sed s/^box.//)

  # creating text users
  TEXT_USER_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
  TEXT_EMAIL_ADDR=text@$HOST
  add_config TEXT_USER_SECRET=$TEXT_USER_SECRET $HOME/.wspecsbox.conf
  tools/mail.py user add $TEXT_EMAIL_ADDR ${TEXT_USER_SECRET:-}
  echo "Creating a new text mail account for $TEXT_EMAIL_ADDR."

  # creating hello users
  HI_USER_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
  HI_EMAIL_ADDR=hi@$HOST
  add_config HI_USER_SECRET=$HI_USER_SECRET $HOME/.wspecsbox.conf
  tools/mail.py user add $HI_EMAIL_ADDR ${HI_USER_SECRET:-}
  echo "Creating a new hello mail account for $HI_EMAIL_ADDR."

  # creating admin users
  EMAIL_ADDR=wspecs@$HOST
  ADMIN_USER_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
  add_config ADMIN_USER_SECRET=$ADMIN_USER_SECRET $HOME/.wspecsbox.conf
  echo
  echo "Creating a new administrative mail account for $EMAIL_ADDR."

  # Create the user's mail account. This will ask for a password if none was given above.
  tools/mail.py user add $EMAIL_ADDR ${ADMIN_USER_SECRET:-}

  # Make it an admin.
  hide_output tools/mail.py user make-admin $EMAIL_ADDR

  # Create an alias to which we'll direct all automatically-created administrative aliases.
  set -e
  tools/mail.py alias add administrator@$PRIMARY_HOSTNAME $EMAIL_ADDR > /dev/null
  set +e
  echo
fi

