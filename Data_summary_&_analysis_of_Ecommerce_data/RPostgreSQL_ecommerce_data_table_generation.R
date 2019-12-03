# Ecommerce_data Import via RPostgreSQL

# data downloaded from kaggle (https://www.kaggle.com/lissetteg/ecommerce-dataset)


#libraries


library(DBI)
library(RPostgreSQL)

#Establishing a connection with server (local)

data_connection<-dbConnect(PostgreSQL(), 
                           user='postgres', 
                           password='**********', 
                           host='localhost')


file_path<-"C:/Users/samee/Desktop/R data/sample_datasets/sql_datasets/ecommerce_data.csv"

data_file<-read.csv(file_path)

#dbSendQuery(data_connection,"SET NAMES utf8mb4;")

dbWriteTable(data_connection,name = 'ecommerce_data',value=data_file,row.names=FALSE)

dbListTables(data_connection)

dbDisconnect(data_connection)
