# Setup For GUI (graphical user interface) if using server and you have full access.

# 1) Installing Nomachine.

- Enter these commands one by one
```
sudo apt update -y && sudo apt upgrade -y
```
```
sudo apt install ubuntu-gnome-desktop -y
```
```
sudo adduser <username>
```

-Then give it password (Dont't leave empty)
-You can skip other fields. 

-Now to give it superuser rights enter this command
```
sudo usermod -aG sudo,adm <username>
```

-To get into root directory of user
```
sudo -i
```

-Now lets check if password is set
```
cat /etc/ssh/sshd_config
```
Now we have to search for PasswordAuthentication if it is yes, you are good to go but if it's not you have to modify it to yes.

-If it's no then let me show how to change it
```
nano /etc/ssh/sshd_config
```

-Remove # before PasswordAuthentication and then change no to yes
-After that then click ctrl+x then Y after that you are good to go 

-Let's download nomachine to screenshare and control via other device 
(For download link search nomachine on browser and get download link for the software which is on VM) 
```
wget <download link for nomachine deb file for x86/64>
```

Lets's run/setup nomachine in VM
```
sudo dpkg -i <name of the nomachine file you downloaded above>
```

Now reboot
```
sudo reboot
```
 
# 2) Adding firewall rules for nomachine.

I) Go to vpc network on website from where you got VM 

II) Click on firewall 

III) Create a new firewall rule

IV) Enter these details for rules

   a) Name - nomachine-fw
   b)Description - nomachine-fw
   c)logs - off
   d)Target Tags - nomachine-fw
   e)source IPv4 Ranges - 0.0.0.0/0
   f)turn on the TCP then in Ports - 4000

V) Now click on create

VI) Turn off VM

VII) Go to VM settings

VIII) Edit the VM

IX) Scroll down to Firewall 

X) Add "nomachine-fw" to network tags

XII) Now save

# Screen sharing or running VM on your device. 

1) Start the VM and copy the external IP

2) Download nomachine in your device 

3) Open nomachine and click on add device

4) Give the machine name and paste the external IP at Host then click add

5) Double click the device you added 

6) Skip all the instructions (You can read too)

7) Now you can see that you are connected 

8) Whenever you stop and then start the VM external IP changes so make sure to edit Host to the new one everytime.




