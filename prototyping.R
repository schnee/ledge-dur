library(yaml)


ledge = yaml.load_file("./data/legislators-historical.yaml")

# want to create a dataframe with id, name, term type, term start, term end, and party out of the ledge object

extractElements = function(e){
  id = e$id$govtrack
  firstName = e$name$first
  lastName = e$name$last
  gender=e$bio$gender
  
  term = e$terms[[1]]
  termStart = term$start
  termEnd = term$end
  party = term$party
  if(is.null(party)) {
    party=NA
  }
  type = term$type
  
  data.frame(id=id, firstName=firstName, lastName=lastName, gender=gender, 
             start=termStart, 
             end=termEnd, 
             party=party, 
             type=type, 
             stringsAsFactors = F)
}

temp = lapply(ledge, extractElements)
ledge_df = bind_rows(temp)

ledge_df$gender = as.factor(ledge_df$gender)
ledge_df$party = as.factor(ledge_df$party)
ledge_df$type = as.factor(ledge_df$type)
