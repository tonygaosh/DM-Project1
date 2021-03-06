#########################
# DM Proj1              #
# 1.3 Bag of Words      #
# 1.4 Word Cloud        #
# 1.5 Length Histo      #
# 1.6 Category Histo    #
# 1.7 Monthly Distri    #
# 2.1 Similarity Matrix #
# 2.2 In-cat Similarity #
# 2.3 Inter-cat Sim     #
#########################
library(tm)
library(qdap)
library(ggplot2)
library(wordcloud)
source("preProcessData.R")

# 1.3 Construct Bag of Words
getBagOfWord <- function(data) {
    corpus <- Corpus(VectorSource(data$Body))

    # get frequency of word in docs
    bow <- llply(corpus, word_list)
    bow <- llply(bow, function(b) b$fwl$all)
    data[["Bag_o_word"]] <- bow

    return (data)
}

# 1.4 Plot Word Cloud
# 1.5 Plot Length Distribution
plotWordPlots <- function(data) {
    corpus <- VCorpus(VectorSource(data$Body))
    dtm <- DocumentTermMatrix(corpus)
    word_freq <- colSums(as.matrix(dtm))

    # find words which occur over 100 times
    words_over_100 <- findFreqTerms(dtm, 100)

    # find 100 most words
    ord <- order(word_freq, decreasing=TRUE)
    words_head_100 <- word_freq[ord[1:100]]

    # draw word cloud of first 100 words
    wordcloud(names(words_head_100), words_head_100, colors=brewer.pal(6, 'Dark2'))

    # Length histogram
    lenlist <- ldply(dtm$dimnames$Term, nchar)
    print(ggplot(lenlist, aes(x=V1)) +
        geom_bar() +
        xlab("长度") + ylab("频数") +
        theme_grey(base_family = "SimHei") +
        geom_text(stat="bin", binwidth=1, aes(label=..count..), vjust=-0.2))

    return (words_over_100)
}

# 1.6 Plot Category
plotCategory <- function(data) {
    catlist <- unlist(data$Classifier)
    catlist <- sort(table(catlist))
    print(ggplot(as.data.frame(catlist), aes(x=catlist, y=Freq)) +
        geom_bar(stat="identity") +
        xlab("Category") + ylab("Frequency") +
        geom_text(aes(label=Freq), hjust=1, colour="white") +
        coord_flip())
    return (catlist)
}

# 1.7 Plot Month
plotMonth <- function(data) {
    month.chn.name <- c("一月","二月","三月","四月","五月","六月",
                        "七月","八月","九月","十月","十一月","十二月")
    tab <- table(factor(months(data$Date), levels=month.chn.name))
    print(ggplot(as.data.frame(tab), aes(x=Var1, y=Freq)) +
        geom_bar(stat="identity") +
        xlab("月份") + ylab("频数") +
        theme_grey(base_family = "SimHei") +
        geom_text(aes(label=Freq), vjust=-0.2))
    return (tab)
}

# 2.1 Compute Similarity
similarity.bog <- function(data) {
    cos.sim <- function(ix) {
        # diag is 1
        if (ix[1] == ix[2]) return (0.5)
        # only calculate half of the matrix
        if (ix[1] > ix[2]) return (0)
        A = data[[ix[1],"Bag_o_word"]]
        B = data[[ix[2],"Bag_o_word"]]
        int_set = intersect(A$WORD, B$WORD)
        distance = 0
        llply(int_set, function(i) {
            distance <<- distance + A[A$WORD==i, "FREQ"]*B[B$WORD==i, "FREQ"]
            } )
        return ( distance / sqrt(sum(A$FREQ^2) * sum(B$FREQ^2)) )
    }
    n <- nrow(data)
    cmb <- expand.grid(i=1:n, j=1:n)
    C <- matrix(apply(cmb, 1, cos.sim), n, n)
    # c plus its transpose
    C <- C + t(C)
    image(c(1:500), c(1:500), C, xlab="", ylab="")
    return (C)
}

# 2.2 In-category Similarity
incat.similarity <- function(data, C) {
    cat <- na.omit(unique(unlist(data$Classifier)))

    # Construct subset mask & Dump article which Body == ""
    catlist <- llply(cat, function(i)
        unlist(alply(data, 1, function(j)
            any(unlist(j[["Classifier"]]) %in% i) & (j[["Body"]] != "")
        , .expand=FALSE))
    )
    listitems <- llply(catlist, function(i) subset(c(1:500), i))
    # Calculate
    aveSim <- unlist(llply(listitems, function(i)
        (sum(C[i, i]) - length(i)) / length(i) / (length(i)-1)
    ))

    # Plot result
    result <- data.frame(Cat=cat, Sim=aveSim)
    result$Cat <- factor(result$Cat, levels = result$Cat[order(result$Sim)])
    print(ggplot(result, aes(x=Cat, y=Sim)) +
        geom_bar(stat="identity") +
        xlab("Category") + ylab("In-category Similarity") +
        geom_text(aes(label=sprintf("%0.3f", round(Sim, digits=3))), hjust=1, colour="white") +
        coord_flip())
    return (result)
}

# 2.3 Inter-category Similarity
inter.cat.similarity <- function(data, C) {
    cat <- c("Education", "Theater")

    # Construct subset mask & Dump article which Body == ""
    catlist <- llply(cat, function(i)
        unlist(alply(data1.1, 1, function(j)
            any(unlist(j[["Classifier"]]) %in% i) & (j[["Body"]] != "")
        , .expand=FALSE))
    )
    listitems <- llply(catlist, function(i) subset(c(1:500), i))

    # Get Inter-cat part of the two sets
    maskedC <- C[setdiff(listitems[[1]], listitems[[2]]),
                 setdiff(listitems[[2]], listitems[[1]])]
    # Calculate Average Similarity
    aveSim <- sum(maskedC) / ncol(maskedC) / nrow(maskedC)
}
