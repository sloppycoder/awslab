yum --enablerepo=mariadb-columnstore clean metadata
yum groups mark remove "MariaDB ColumnStore"
yum groupinstall "MariaDB ColumnStore"
yum --enablerepo=mariadb-columnstore-api clean metadata
yum install -y mariadb-columnstore-api
yum --enablerepo=mariadb-columnstore-tools clean metadata
yum install -y mariadb-columnstore-tools
yum --enablerepo=mariadb-maxscale clean metadata
yum install -y maxscale maxscale-cdc-connector
yum --enablerepo=mariadb-columnstore-data-adapters clean metadata
yum install -y mariadb-columnstore-maxscale-cdc-adapters
yum install -y mariadb-columnstore-kafka-adapters

