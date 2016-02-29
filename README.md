This script is meant for Icinga 1.x; and probably would not work in Icinga 2.

If you use a monitoring system like Icinga, you probably get your alerts via email. You might have already thought about the possibility of acknowledging emails by just replying to them, and may have even implemented it, but this script goes a step further than that and allows you to add expiration times to your acknowledgements, which is important so that you don't have your team forget about acknowledged alerts. 

_(Unfamiliar with expiration times on acknowledgements? You might be coming from the Nagios world; one major advantage Icinga has over Nagios is being able to set an expiration time on acknowledgements. The problem with plain acknowledgements is that, since one would get emails every hour by default unless a problem is acked, an admin would tend to ack a non-critical alert thinking they'd attend to it "later", but the event is eventually forgotten and that "later" never happens, resulting in the issue raising it's head again once it's critical. With expiration dates on acknowledgements, Icinga would mute alerts from the service until either the state changes (eg. to critical), or until the acknowledgement expires on the given time.)_

So with this script set up, if you get an email from Icinga like "PROBLEM: rizvir-web/Root partition is WARNING", and think you'd fix it in the night, you can just reply to the email with:

```
Expire 21:00. Will free up space later.
```

Icinga would then reply to your team in the server's $contacts with:

```
***** Icinga *****

Notification Type: ACKNOWLEDGEMENT

Service: Root partition
Host: rizvir-web
Host alias: RizviR web server
State: WARNING


Additional Info:

DISK WARNING - free space: / 26715 MB (6% inode=90%):
Acknowledged via email by rizvir@fakemail.com. Expire 21:00. Will free up space later.
```

Other ways you can reply include:

```
Expire now +2 hours. Some comment.
Expire tomorrow. Some comment.
Expire Wednesday 13:00. Some comment.
Expire wed 13:00. Some comment. 
Expire next week Sunday 22:00. Some comment. 
Just Some comment without an expiry for no expiration.
```

Unfortunately setting this script up isn't very streamlined; you can follow the steps below:

- Have Postfix on the Icinga server listening for emails _(in theory, one could possibly also just use fetchmail as well which can use pop3/imap to fetch emails from an email address every few minutes, instead of listening for emails directly)_. Emails don't need MX records, just the A record is fine, so you can have your alert replies go to say icinga@icinga.fqdn.yourdomain.com. You can configure iptables to only allow port 25 from your actual mail server's IP; to prevent random people from acknowledging your alerts. 

- You'll need some way to send emails to the script. One easy method is by installing `maildrop`. Once you install it, add this to **/etc/postfix/main.cf** :

```
mailbox_command = /usr/bin/maildrop -d ${USER}
maildrop_destination_recipient_limit = 1
```

- Make sure your icinga user has a home directory, and create a **/home/icinga/.maildroprc** file (or whatever the homedir is set to) with (modify as required):
```
if (/^X-Original-To:.*icinga@yourdomain.*/)
{
	exception {
		log "Passing mail to icinga acknowledgement"
		to "|/usr/local/bin/acknowledge_email.sh"
	}
}
```


- Modify Icinga's **commands.cfg** file, and change the notify-host-by-email & notify-service-by-email to add some stuff read by the script, as well as show the acknowledgement comment for your team:

```
define command{
        command_name    notify-host-by-email
        command_line    /usr/bin/printf "%b" "***** Icinga *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nHost alias: $HOSTALIAS$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n$HOSTACKCOMMENT$\n" | /bin/mail -r "Nagios <icinga@your.domain.com>" -s "$NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$" $CONTACTEMAIL$
}

define command{
        command_name    notify-service-by-email
        command_line    /usr/bin/printf "%b" "***** Icinga *****\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTNAME$\nHost alias: $HOSTALIAS$\nState: $SERVICESTATE$\n\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n$SERVICEACKCOMMENT$ \n | /bin/mail -r "Nagios <icinga@your.domain.com>" -s "$NOTIFICATIONTYPE$: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$" $CONTACTEMAIL$
}
```

Change the email address (icinga@your.domain.com) above for the visible From address (used while replying).

- Copy the **acknowledge_email.sh** script to /usr/local/bin/ , and modify the variables at the top with your icinga.cmd location.

- Test it out by replying to an alert, seeing if postfix received it and sent it to maildrop, then whether maildrop sent it to the script, and then whether the script was able to set the expiry (see the Icinga and script logs).



