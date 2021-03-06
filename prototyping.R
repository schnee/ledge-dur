library(yaml)
library(dplyr)
library(lubridate)
library(ggplot2)
library(ggalt)
library(ggthemes)
library(tidyr)
library(httr)

# points to the source-code-controlled data
yaml_url <-
  "https://raw.githubusercontent.com/unitedstates/congress-legislators/master/legislators-historical.yaml"

r <- GET(yaml_url)
if (r$status_code != 200) {
  stop("Bad URL Fetch")
}

ledge <- yaml.load(content(r, "text"))
rm(r)

# want to create a dataframe with id, name, term type, term start, term end, and party out of the ledge object

extractElements <- function(e) {
  id <- e$id$govtrack
  firstName <- e$name$first
  lastName <- e$name$last
  gender <- e$bio$gender
  bday <- if (is.null(e$bio$birthday))
    NA
  else
    e$bio$birthday
  
  terms = bind_rows(lapply(
    e$terms,
    FUN = function(t)
      data.frame(
        type = t$type,
        start = t$start,
        end = t$end,
        party = if (is.null(t$party))
          "Unknown"
        else
          t$party,
        stringsAsFactors = F
      )
  ))
  
  terms <- terms %>% arrange(start)
  
  # some legislators will jump between the House and the Senate, which is encoded
  # as "rep" or "sen" in terms$type. The RLE function figures out how many terms
  # each "run" of House or Senate lasts.
  
  runs <- rle(terms$type)
  
  # these statements pick out the start and end of each run, along with the parties
  # and the body served (the type).
  
  # Note that it is possible for a legislator to switch parties; I'm not dealing with
  # that. yet.
  
  starts <- terms$start[c(1, cumsum(head(runs$lengths, -1)) + 1)]
  ends <- terms$end[cumsum(runs$lengths)]
  parties <- terms$party[cumsum(runs$lengths)]
  types <- terms$type[cumsum(runs$lengths)]
  
  data.frame(
    id = rep(id, length(starts)),
    firstName = rep(firstName, length(starts)),
    lastName = rep(lastName, length(starts)),
    gender = rep(gender, length(starts)),
    birthday = rep(bday, length(starts)),
    numTerms = runs$lengths,
    start = starts,
    end = ends,
    party = parties,
    type = types,
    stringsAsFactors = FALSE
  )
}

splinePoints <- function(theIndex, df) {
  e <- df[theIndex, ]
  
  # peak of the spline is the number of terms served
  peak <- e$numTerms
  
  # this output dataframe defines the shape of the spline. Lots of
  # customization here.
  data.frame(
    x = as.Date(quantile(as.numeric(c(
      e$start, e$end
    )), probs = c(0, .15, .85, 1)), origin = "1970-01-01"),
    y = c(0, peak * .85, peak * .85, 0),
    splineIndex = e$id,
    party = e$party
  )
}


temp = lapply(ledge, extractElements)
ledge_df = bind_rows(temp)
rm(ledge)

ledge_df$start = ymd(ledge_df$start)
ledge_df$end <- ymd(ledge_df$end)
ledge_df$gender <- as.factor(ledge_df$gender)
ledge_df$party <- as.factor(ledge_df$party)
ledge_df$type <- as.factor(ledge_df$type)
ledge_df$dur <- ledge_df$end - ledge_df$start

## Show the mismash of all the parties
body <- ledge_df %>%
  filter(dur < 22000) %>%
  filter(type == "rep") %>%
  #filter(party %in% c("Democrat", "Republican"))%>%
  arrange(start, end)

# cheap and dirty way to move along a dataframe
theSplines <- lapply(X = seq_len(nrow(body)), splinePoints, body) %>% bind_rows(.)

all_parties <-
  ggplot(theSplines, aes(x, y, group = splineIndex, colour = party)) +
  geom_xspline(spline_shape = -0.5, size = 0.2) +
  #scale_color_manual("US Senate", values=c("blue", "red")) +
  theme_few() + theme(
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.border = element_blank(),
    legend.position = "none"
  ) +
  xlab("Year")

## Generate the just the Repub / Democ for the HoR
rm(theSplines, body)
body <- ledge_df %>%
  filter(dur < 22000) %>%
  filter(type == "rep") %>%
  filter(party %in% c("Democrat", "Republican")) %>%
  arrange(start, end) %>%
  mutate(numTerms = if_else(party == "Republican", numTerms * -1, numTerms * 1))

# cheap and dirty way to move along a dataframe
theSplines <- lapply(X = seq_len(nrow(body)), splinePoints, body) %>% bind_rows(.)

hor_big_two <-
  ggplot(theSplines, aes(x, y, group = splineIndex, colour = party)) +
  geom_xspline(spline_shape = -0.5, size = 0.2) +
  scale_color_manual("US House of Representatives", values = c("blue", "red")) +
  theme_few() + theme(
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.border = element_blank()
  ) +
  xlab("Year")




## Generate the just the Repub / Democ for the Senate
rm(theSplines, body)
body <- ledge_df %>%
  filter(dur < 22000) %>%
  filter(type == "sen") %>%
  filter(party %in% c("Democrat", "Republican")) %>%
  arrange(start, end) %>%
  mutate(numTerms = if_else(party == "Republican", numTerms * -1, numTerms * 1))

# cheap and dirty way to move along a dataframe
theSplines <- lapply(X = seq_len(nrow(body)), splinePoints, body) %>% bind_rows(.)

sen_big_two <-
  ggplot(theSplines, aes(x, y, group = splineIndex, colour = party)) +
  geom_xspline(spline_shape = -0.5, size = 0.2) +
  scale_color_manual("US Senate", values = c("blue", "red")) +
  theme_few() + theme(
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.border = element_blank()
  ) +
  xlab("Year")

##
# save all the plots

ggsave(
  "./viz/all-parties-hor.png",
  all_parties,
  width = 12,
  height = 6,
  dpi = 100
)

ggsave(
  "./viz/hor-big-two.png",
  hor_big_two,
  width = 12,
  height = 6,
  dpi = 100
)

ggsave(
  "./viz/sen-big-two.png",
  sen_big_two,
  width = 12,
  height = 6,
  dpi = 100
)


bks = seq(trunc(min(year(body$end)) / 10) * 10, trunc(max(year(body$end)) / 10) * 10 + 10, 10)
body$decade = bks[cut(year(body$end), breaks = bks, labels = FALSE)]

decades <- body %>% filter(decade > "1900") %>%
  group_by(decade, party) %>%
  summarize(aveDur = mean(as.numeric(dur, units = "days") / 365),
            aveTerms = mean(abs(numTerms)))

# the average terms served by party per decade
decades %>%
  select(decade, party, aveTerms) %>%
  spread(party, aveTerms) %>%
  knitr::kable(digits = 0)

ggplot(decades, aes(x = decade, y = aveTerms, colour = party)) +
  geom_point() + geom_smooth(
    method = "lm",
    se = F,
    linetype = "dashed",
    size = 0.5
  ) +
  scale_color_manual("US Senate", values = c("blue", "red")) +
  theme_few() + ylab("Average Number of Terms") +
  theme(panel.border = element_blank()) + coord_cartesian(ylim = c(0, 8))
