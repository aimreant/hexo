# Install java and tomcat
apt install -y language-pack-zh-hant-base language-pack-zh-hans-base
apt install -y openjdk-8-jre openjdk-8-jdk
wget http://apache.fayea.com/tomcat/tomcat-8/v8.0.43/bin/apache-tomcat-8.0.43.tar.gz
tar zxvf apache-tomcat-8.0.43.tar.gz

# Download jenkins
wget http://ftp-chi.osuosl.org/pub/jenkins/war-stable/2.46.1/jenkins.war
mv jenkins.war apache-tomcat-8.0.43/webapps/
./apache-tomcat-8.0.43/bin/startup.sh

# Install nodejs
wget https://nodejs.org/dist/v6.10.2/node-v6.10.2.tar.gz
tar zxvf node-v6.10.2.tar.gz
cd node-v6.10.2
./configure
make -j2 && make install -j2
cd ..

# Install hexo
npm install hexo-cli -g
hexo init hexo
cd hexo
npm install
hexo g
cd ..

# Install nginx
apt install -y nginx
#xxx
nginx -s reload
