# A/B testing 


# Downloading and Importing data from the website https://www.datacamp.com/courses/ab-testing-in-r


# The data contains a clickstream dataset of like and share actions of a website where a change a word on the webpage is changed from tools to tips for one month along with average time spent on the website for each observation


#Libraries used


library(tidyverse)

library(magrittr)

library(lubridate)

library(scales)

library(psych)

library(plotly)


# File is downloaded in the working directory


# Download file (in the working directory)


# download.file("https://assets.datacamp.com/production/repositories/2292/datasets/b502094e5de478105cccea959d4f915a7c0afe35/data_viz_website_2018_04.csv",
#                'A_B_test.csv',
#                quiet = TRUE)


# Import data in R


data_file_path<-paste0(getwd(),'/A_B_test.csv')


data_file<-read_csv(data_file_path)


str(data_file)


#view(data_file)


### Exploring and visualizing the data


##1. Time duration of the dataset


range(data_file$visit_date)


##2. Average conversion rate of likes and shares for condition: tools and tips


#a. Data summary


data_file%>%
    gather(click_types,
           click_values,
           clicked_like:clicked_share)%>%
    group_by(click_types,
             condition)%>%
    summarise(conversion_rate=mean(click_values))


#b. Data Visualization


data_file%>%
    gather(click_types,
           click_values,
           clicked_like:clicked_share)%>%
    group_by(click_types,
             condition)%>%
    summarise(conversion_rate=mean(click_values))%>%
    spread(condition,conversion_rate)%>%
    plot_ly(x = ~click_types,
            y=~tips,
            type = "bar",
            name = 'tips')%>%
    add_trace(y = ~tools, name = 'tools')%>%
    layout(barmode = 'group',
           title = 'Barchart of conversion rates of likes and shares',
           xaxis = list(title = "Variant"),
           yaxis = list(title = "Conversion rates"))


##3. mean weekly click types based on the condition


#a. Obtaining the mean weekly click types based on the condition


data_file%>%
    gather(click_types,
           click_values,
           clicked_like:clicked_share)%>%
    group_by(week(visit_date),
             condition,
             click_types)%>%
    summarise(conversion_rate=mean(click_values))%>%
    arrange(`week(visit_date)`)


#b. Visualization of the above data


mean_clicks_viz<-data_file%>%
    gather(click_types,
           click_values,
           clicked_like:clicked_share)%>%
    group_by(week(visit_date),
             condition,
             click_types)%>%
    summarise(conversion_rate=mean(click_values))%>%
    ggplot(aes(x=`week(visit_date)`,
               y=conversion_rate,
               col=condition,
               group=condition))+
    geom_point(size=3)+
    geom_line(lwd=0.9)+
    scale_y_continuous(limits = c(0, 1),
                       labels = percent)+
    facet_grid(~click_types,
               scales = 'free')+
    theme_bw(base_size = 18)+
    scale_color_manual(values = c("steelblue","forestgreen"))+
    ylab("conversion rates")+
    xlab("week")


mean_clicks_viz


# The above plot and data summary shows that the average conversion rates vary in the 'like' action depending on the condition. The word 'tips' seems to have a higher conversion rate than the word 'tools'


#### We can check whether the difference in likes and shares between the two variants is significant respectively, binary logistic regression is performed with clicks and shares being the dependent variable and the variant condition (tips and tools) being the independent descriptor. To view the results in a more effective way, 'broom' package is used


require(broom)


# Logistic regression for testing significance 


#a. clicked like


logistic_reg_model1 <- glm(clicked_like ~ condition,
                           family = "binomial",
                           data = data_file) %>%
    tidy()


logistic_reg_model1


# Results from the model clearly indicate a significance between the 'like' action conversion rates of the two variants


#b. clicked shared


logistic_reg_model2 <- glm(clicked_share ~ condition,
                           family = "binomial",
                           data = data_file) %>%
    tidy()


logistic_reg_model2


# Results from the model clearly indicate no significance between the 'share' action conversion rates of the two variants


# From the Figure 'a' from subsection 2 and subsequent logistic regression analysis (logistic_reg_model2), it can be seen that the conversion rates of clicked share was not statistically significant between the two variants. 


# Hypothetically, if the base conversion rate of clicked share needs to be improved by say 5%, the new sample size for a followup experiment needs to be determined


require(powerMediation)


# Computing the sample size 


total_sample_size <- SSizeLogisticBin(p1 = 0.032,
                                      p2 = 0.082,
                                      B = 0.5,
                                      a = 0.05,
                                      p = 0.8)


total_sample_size


### Sequential Analysis


#Sequential analysis performed based on the sample size estimated above for 3 stopping points to ascertain at which sampling time interval should the sample collection be stopped (if at all) given that the null hypothesis is rejected(at that stopping point) based on the data obtained from the sample size at the interval (Please note that this number of samples is for purely for demonstration of the technique and is not necessarily a part of the workflow.A different arbitary number can be also used in its place)


#This will ensure limiting 'p-hacking' and other factors (resources) used in generating the data


#At any of the stopping points, if the analysis is performed and it yields statistically significant results (based on the p value obtained from the sequential analysis), sequential analsysis will be stopped


#Sequential analysis will be carried out using the package 'gsDesign'


if(!require(gsDesgin))install.packages('gsDesgin') 


# Performing sequential analysis


seq_analysis_click_data <- gsDesign(k = 3, # number of 
                                    test.type = 1, # Two or one sided test
                                    alpha = 0.05,
                                    beta = 0.2, # (1 - power) value
                                    sfu = "Pocock") # how the p values are calculated


# Fill in max number of points and compute points per group and find stopping points (here using ths total_sample_size calculated above)


paste('Total sampling points for the current experiment are:',total_sample_size)


# Since there are two variants of the condition (tips and tools) the sample size is divided in 2 equal sizes


samples_per_grp <- total_sample_size / 2


# Stopping points are then calculated based on the sequential analysis  and the sample size per group calculated above


stop_points <- samples_per_grp * seq_analysis_click_data$timing


stop_points


# At any of the stop points if we perform analysis and get a significant result, the experiment can be stopped


###. Exploring and asessing the difference in the mean weekly time spent based on the two variants (tips and tools)


#a. Obtaining the mean weekly click types based on the condition


data_file%>%
    gather(click_types,
           click_values,
           clicked_article:clicked_share)%>%
    group_by(condition)%>%
    summarise(time_spent=mean(time_spent_homepage_sec,na.rm = T))%>%
    arrange(desc(time_spent))


#b. Visualization of the above data


time_data_week_viz<-data_file%>%
    gather(click_types,
           click_values,
           clicked_like:clicked_share)%>%
    group_by(week(visit_date),
             condition)%>%
    summarise(time_spent=mean(time_spent_homepage_sec))%>%
    ggplot(aes(x=`week(visit_date)`,
               y=time_spent,
               fill=condition))+
    geom_boxplot(col='black',
                 lwd=0.7)+
    theme_bw(base_size = 18)+
    scale_color_manual(values = c("steelblue","forestgreen"))+
    ylab("avg time spent (seconds)")+
    xlab("week")+
    scale_fill_manual(values = c("steelblue",'grey50'))


time_data_week_viz


# The data visualization shows weekly variation in the time spent on the homepage given the condition (the word 'tips' or 'tools'). Based on the boxplot, the median time spent seems slightly dissimilar for both the conditions while data summary shows that the means are equal


# We use a t-test to check whether the difference in the time spent on homepage between the two variants is statsitically significant or not


ab_experiment_results <- t.test(time_spent_homepage_sec ~ condition,
                                data = data_file)

#Results


ab_experiment_results


# From the analsysis it is clear that there is no significant difference in the time spent on the webpages using each of the two variants


##WIP###


