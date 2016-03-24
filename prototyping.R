library(yaml)
library(dplyr)
library(lubridate)
library(ggplot2)
library(ggalt)
library(ggthemes)


ledge <- yaml.load_file("./data/legislators-historical.yaml")

# want to create a dataframe with id, name, term type, term start, term end, and party out of the ledge object

extractElements <- function(e){
  id <- e$id$govtrack
  firstName <- e$name$first
  lastName <- e$name$last
  gender<-e$bio$gender

  numTerms = length(e$terms)
  firstTerm <- e$terms[[1]]
  lastTerm <- e$terms[[numTerms]]
  termStart <- firstTerm$start
  termEnd <- lastTerm$end
  party <- firstTerm$party
  if(is.null(party)) {
    party<-"Unknown"
  }
  type <- firstTerm$type
  
  data.frame(id=id, firstName=firstName, lastName=lastName, gender=gender, 
             start=termStart, 
             end=termEnd, 
             party=party, 
             type=type, 
             stringsAsFactors = F)
}

splinePoints <- function(theIndex, df){
  
  e <- df[df$id==theIndex,]
  
  # the number of days is how high the spline should reach
  peak <- e$end - e$start
  
  if(!is.null(e$party) && e$party=="Republican"){
    peak<--1*peak
  }
  
  # this output dataframe defines the shape of the spline. Lots of 
  # customization here.
  data.frame(x=quantile(c(e$start, e$end), probs=c(0,.15,.85,1)), 
             y=c(0, peak*.85, peak*.85, 0),
             splineIndex = e$id,
             party=e$party)
}


temp = lapply(ledge, extractElements)
ledge_df = bind_rows(temp)

ledge_df$start= ymd(ledge_df$start)
ledge_df$end <- ymd(ledge_df$end)
ledge_df$gender <- as.factor(ledge_df$gender)
ledge_df$party <- as.factor(ledge_df$party)
ledge_df$type <- as.factor(ledge_df$type)
ledge_df$dur <- ledge_df$end - ledge_df$start


body <- ledge_df %>% 
  filter(dur < 22000) %>%
  filter(type=="rep") %>% 
  filter(party %in% c("Democrat", "Republican"))%>% 
  arrange(start, end) 

temp <- lapply(X=body$id, FUN=splinePoints, body)
theSplines <- bind_rows(temp)

ggplot(theSplines, aes(x, y, group=splineIndex, colour=party)) + 
  geom_xspline(spline_shape = -0.5, size=0.2) +
  scale_color_manual("US House", values=c("blue", "red")) +
  theme_few() + theme(axis.text.y = element_blank(),
                      axis.title.y = element_blank(),
                      axis.ticks.y = element_blank(),
                      panel.border = element_blank()) +
  xlab("Year")
