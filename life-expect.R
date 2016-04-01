require(rvest)
require(readr)
life_html <- read_html("http://www.infoplease.com/ipa/A0005140.html")
life_df <- life_html %>% html_node(css = "table#A0005141") %>% html_table()

life_df %>% write_csv("./data/life_df.csv")

life_df <- read_csv("./data/life_df.csv")
