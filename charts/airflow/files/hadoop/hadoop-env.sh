# Use YARN for all hadoop commands
export HADOOP_MAPRED_HOME=/usr/lib/hadoop-mapreduce

# This extra config jar is useful to use the RollingFileAppender log4j class.
# Context: https://phabricator.wikimedia.org/T276906
export HADOOP_CLASSPATH=/usr/share/java/apache-log4j-extras.jar:${HADOOP_CLASSPATH}
