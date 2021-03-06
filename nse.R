
#########################################
### Cleaning Workspace
#########################################

rm(list=ls())

#########################################
### Insatalling Packages and Loading Libraies
#########################################
#install.packages("dplyr")
#install.packages("ggplot2")
#install.packages("data.table")
#install.packages("gridExtra")
#install.packages("normalr")
#install.packages("ggiraphExtra")
#install.packages("plotly")
#install.packages("lubridate")
# install.packages("reshape")
library(lubridate)
library(dplyr)
library(ggplot2)
library(data.table)
library(gridExtra)
require(gridExtra)
library(normalr)
require(ggiraph)
require(ggiraphExtra)
library(reshape2)
library(plotly)
library(tidyr)
library(stringr)
library(forecast)
library(reshape) 
#### Loadingg dataset from csv
nse_data <- read.csv(file="prices-split-adjusted.csv", header=TRUE, sep=",",check.names=FALSE)
names(nse_data)<-str_replace_all(names(nse_data),c(" "="_"))

fundamentals_data <- read.csv(file="fundamentals.csv", header=TRUE, sep=",",check.names=FALSE)
securities_data <- read.csv(file="securities.csv", header=TRUE, sep=",",check.names=FALSE)
###########
head(nse_data)
head(fundamentals_data)
head(securities_data)
###### replacingg " " with "_"
names(securities_data)<-str_replace_all(names(securities_data),c(" "="_"))
names(fundamentals_data)<-str_replace_all(names(fundamentals_data),c(" "="_"))
names(nse_data)<-str_replace_all(names(nse_data),c(" "="_"))
fundamentals_data = subset(fundamentals_data, select = -c(1) )
###### filtering info tech 
securities_it_data<-securities_data %>% 
  filter(GICS_Sector == "Information Technology")
symbol_list<-securities_it_data['Ticker_symbol']

nse_it_data<-nse_data %>% 
  filter(symbol %in% symbol_list[['Ticker_symbol']])

fundamental_it_data<-fundamentals_data %>% 
  filter(Ticker_Symbol %in% symbol_list[['Ticker_symbol']])

top5_list<-c("GOOGL","AAPL","FB","MSFT","INTC")
#filtering top 5 data
nse_top5_data<-nse_it_data %>%
  filter(symbol %in% top5_list)
names(nse_top5_data)<-str_replace_all(names(nse_top5_data),c("date"="date_t"))
ggplotly(ggplot(nse_top5_data)+geom_line(aes(as.Date(date_t), close,color=symbol))
         +xlab("Years") + ylab("Closing Stock Price")+ ggtitle("Trend of Big Five Stocks"))
###subset by year
nse_top5_data$date_t <- ymd(nse_top5_data$date_t)
nse_top5_data$year <- year(nse_top5_data$date_t)
nse_top5_data_train<- subset(nse_top5_data, year <= 2015)
nse_top5_data_test<- subset(nse_top5_data, year > 2015)


###### ggplot for holtwinters

###### prediction
predict_stock <- function(company_symbol) {
  error.ribbon='#16A085'
  nse_data_train<- subset(nse_top5_data_train, symbol == company_symbol)
  nse_data_train$date_t <- strptime(nse_data_train$date_t, "%Y-%m-%d" )
  nse_data_train$date_t <- as.POSIXct(nse_data_train$date_t)
  nse_data_train <- mutate(nse_data_train, Yearday = paste(year(date_t), formatC(month(date_t), width = 2, flag = "0"),
                                                           formatC(mday(date_t), width = 2, flag = "0")))
  
  nse_data_test<- subset(nse_top5_data_test, symbol == company_symbol)
  nse_data_test$date_t <- strptime(nse_data_test$date_t, "%Y-%m-%d" )
  nse_data_test$date_t <- as.POSIXct(nse_data_test$date_t)
  nse_data_test <- mutate(nse_data_test, Yearday = paste(year(date_t), formatC(month(date_t), width = 2, flag = "0"),
                                                         formatC(mday(date_t), width = 2, flag = "0")))
  
  nse_temp<- subset(nse_data_train, year == min(nse_data_train$year)+1)
  myts <- ts(nse_data_train$close, frequency=251,start =min(nse_data_train$year), end =2016)
  myts_2 <- ts(nse_data_test$close, frequency=251,start =2016, end =2017)
  
  hw_object<-HoltWinters(myts,l.start = nse_temp[1:1,]$close,start.periods =7,beta = 0.07, gamma = 0.12 ,seasonal = "mult",alpha = 0.452)
  forecast<-predict(hw_object,  n.ahead=251,  prediction.interval=T,level = 0.35)
  
  for_values<-data.frame(time=round(time(forecast),  3),  value_forecast=as.data.frame(forecast)$fit,  dev=as.data.frame(forecast)$upr-as.data.frame(forecast)$fit)
  fitted_values<-data.frame(time=round(time(hw_object$fitted),  3),  value_fitted=as.data.frame(hw_object$fitted)$xhat)
  actual_values_1<-data.frame(time=round(time(hw_object$x),  3),  Actual=c(hw_object$x))
  actual_values_2<-data.frame(time=round(time(myts_2),  3),  Actual=c(nse_data_test$close))
  
  actual_values<-merge(actual_values_1,  actual_values_2,  by='time',  all=TRUE)
  actual_values$Actual <- rowMeans(actual_values[, c("Actual.x", "Actual.y")], na.rm=TRUE)
  actual_values = subset(actual_values, select = -c(Actual.x, Actual.y) )
  
  
  graphset<-merge(actual_values,  fitted_values,  by='time',  all=TRUE)
  #acc_model<-sqrt(mean((graphset$Actual - graphset$value_forecast)^2,na.rm = TRUE))
  graphset<-merge(graphset,  for_values,  all=TRUE,  by='time')
  graphset[is.na(graphset$dev),  ]$dev<-0
  
  graphset$Fitted<-c(rep(NA,  NROW(graphset)-(NROW(for_values) + NROW(fitted_values))),  fitted_values$value_fitted,  for_values$value_forecast)
  
  
  graphset.melt<-melt(graphset[, c('time', 'Actual', 'Fitted')], id='time')
  
  p<-ggplotly(ggplot(graphset.melt,  aes(x=graphset.melt$time,  y=graphset.melt$value))+ xlab('Time') + ylab('Value')+ ggtitle(paste("Predicted value of Stocks using Holt-Winters Process for ",company_symbol,"with mean Error ",abs(mean((graphset$Actual - graphset$value_forecast),na.rm = TRUE))))+ geom_line(aes(colour=graphset.melt$variable))+scale_color_manual(values=c('#E74C3C','#2471A3'))+theme_bw()+geom_ribbon(data=graphset, aes(x=graphset$time, y=graphset$Fitted, ymin=graphset$Fitted-graphset$dev,  ymax=graphset$Fitted + graphset$dev),  alpha=.3,  fill=error.ribbon))
  return(p)
  
}

predict_stock('GOOGL')
#predict_stock('AAPL')
#predict_stock('FB')
#predict_stock('MSFT')
#predict_stock('INTC')




###calculate mean for D
nse_data$date <- ymd(nse_data$date)
nse_data$year <- year(nse_data$date)
mean_val <- aggregate(close ~ symbol+year,nse_data,mean)

names(securities_data)[names(securities_data)=='Ticker_symbol']<-'Ticker_Symbol'
securities_data.short <-securities_data[,c(1,4,5)]
head(securities_data.short)
nse_sec_data <- merge(fundamental_it_data,securities_data.short,by='Ticker_Symbol',all.x=TRUE)
nse_sec_data$Period_Ending <- ymd(nse_sec_data$Period_Ending)
nse_sec_data$year <- year(nse_sec_data$Period_Ending)

mean_val$index <- paste(as.character(mean_val$symbol),mean_val$year,sep=" ")
nse_sec_data$index <- paste(as.character(nse_sec_data$Ticker_Symbol),nse_sec_data$year,sep=" ")

nse_sec_data <- merge(nse_sec_data,mean_val[,3:4],by = "index", all.x = TRUE)

names(nse_sec_data)[names(nse_sec_data)=="close"]<- "close_price"
names(nse_sec_data)[names(nse_sec_data)=="GICS_Sector"]<- "Industry_Type"

nse_sec_data<- subset(nse_sec_data, year > 2012 & year <= 2016)
nse_sec_data$Period_Ending <- as.Date(nse_sec_data$Period_Ending)
nse_sec_data$year <- year(nse_sec_data$Period_Ending)
list_na <- colnames(nse_sec_data)[apply(nse_sec_data,2,anyNA)]

na_check <- is.na(nse_sec_data$Estimated_Shares_Outstanding)
na_val <- which(na_check==c("TRUE"))
nse_sec_data = nse_sec_data[-na_val,]

nse_sec_data$market_val <- nse_sec_data$close_price * nse_sec_data$Estimated_Shares_Outstanding#NFLX,V

#######calculate z-score
nse_sec_data$val_A <- (nse_sec_data$Total_Current_Assets- nse_sec_data$Total_Current_Liabilities)/nse_sec_data$Total_Assets
nse_sec_data$val_B <- nse_sec_data$Retained_Earnings/nse_sec_data$Total_Assets
nse_sec_data$val_C <- nse_sec_data$Earnings_Before_Interest_and_Tax/nse_sec_data$Total_Assets
nse_sec_data$val_D <- nse_sec_data$market_val/(nse_sec_data$Total_Assets-nse_sec_data$Total_Liabilities)
nse_sec_data$val_E <- nse_sec_data$Total_Revenue / nse_sec_data$Total_Assets

nse_sec_data$z_score <- 1.2 *nse_sec_data$val_A + 1.4* nse_sec_data$val_B + 3.3*nse_sec_data$val_C +0.6*nse_sec_data$val_D +nse_sec_data$val_E

distress_list <- unique(subset(nse_sec_data , z_score<=1.81)['Ticker_Symbol'])
gray_list <- unique(subset(nse_sec_data , z_score> 1.81 & z_score<=2.99)['Ticker_Symbol'])
safe_list <- unique(subset(nse_sec_data ,z_score>2.99)['Ticker_Symbol'])
set.seed(1010)
subset_safe <-floor(0.45*nrow(safe_list))
train_ind <-sample(seq_len(nrow(safe_list)),size = subset_safe)
safe_20 <-data.frame(safe_list[train_ind,])

distress_zone<-nse_sec_data %>% 
  filter(Ticker_Symbol %in% distress_list[['Ticker_Symbol']])

gray_zone<-nse_sec_data %>% 
  filter(Ticker_Symbol %in% gray_list[['Ticker_Symbol']])

safe_zone<-nse_sec_data %>% 
  filter(Ticker_Symbol %in% safe_20[,1])


ggplotly(ggplot(distress_zone, aes(x=year, y=z_score,fill=Ticker_Symbol))+geom_bar(stat="identity")+geom_hline(yintercept=1.81,color="darkred")+facet_wrap(~Ticker_Symbol)+ggtitle("Companies in Distress Zone"))
ggplotly(ggplot(gray_zone, aes(x=year, y=z_score,fill=Ticker_Symbol))+geom_bar(stat="identity")+geom_hline(yintercept=1.81,color="darkred")+geom_hline(yintercept=2.99,color="darkred")+facet_wrap(~Ticker_Symbol)+ggtitle("Companies in Gray Zone"))
ggplotly(ggplot(safe_zone, aes(x=year, y=z_score,fill=Ticker_Symbol))+geom_bar(stat="identity")+geom_hline(yintercept=2.99,color="darkred")+facet_wrap(~Ticker_Symbol)+ggtitle("Companies in Safe Zone"))

  