#!/usr/bin/env Rscript

library(pafr)
library(data.table)
library(ggplot2)

#############
# FUNCTIONS #
#############


# Adjust the PAF coordinates to the continuous x-axis
adjust_coords <- function(qname, qstart, qend, tname, tstart, tend) {
  my_qstart <- lookup_qstart(qname)
  my_tstart <- lookup_tstart(tname)
  return(
    data.table(
      adj_qstart = qstart + my_qstart,
      adj_qend = qend + my_qstart,
      adj_tstart = tstart + my_tstart,
      adj_tend = tend + my_tstart
    )
  )
}

# calculate spacing between contigs so the ref and query take up the same x-axis
# space
get_padding <- function(paf) {
  tlen_sum <- unique(paf, by = "tname")[, sum(tlen)]
  tgaps_total <- paf[, length(unique(tname))]

  qlen_sum <- unique(paf, by = "qname")[, sum(qlen)]
  qgaps_total <- paf[, length(unique(qname))]

  # the minumum gap is going to be one tenth of the x-axis space
  if (tlen_sum > qlen_sum) {
    min_gap <- (tlen_sum * gap_size) / tgaps_total
    full_tlen <- tlen_sum + (tgaps_total * min_gap)

    total_qpadding <- full_tlen - qlen_sum
    return(
      c(
        "t_padding" = min_gap,
        "q_padding" = total_qpadding / qgaps_total
      )
    )
  } else if (tlen_sum < qlen_sum) {
    min_gap <- (qlen_sum * gap_size) / qgaps_total
    full_qlen <- qlen_sum + (qgaps_total * min_gap)

    total_tpadding <- full_qlen - tlen_sum

    return(
      c(
        "t_padding" = total_tpadding / tgaps_total,
        "q_padding" = min_gap
      )
    )
  } else {
    min_gap <- (tlen_sum * gap_size) / tgaps_total
    return(
      c(
        "t_padding" = min_gap,
        "q_padding" = min_gap
      )
    )
  }
}

# offsets for the adjusted coordinates
lookup_tstart <- function(x) {
  return(unique(tstarts[tname == x, shift_tstart]))
}


lookup_qstart <- function(x) {
  return(unique(qstarts[qname == x, shift_qstart]))
}


###########
# GLOBALS #
###########

agp_file <- "data/galaxy_out.agp"
paf_file <- "data/galaxy_out.paf"
plot_file <- "plot.pdf"

# PAF column spec
sort_columns <- c("tname", "tstart", "tend", "qname", "qstart", "qend")

# plot paramaters
t_y <- 1
q_y <- 2
min_nmatch <- 20e3
gap_size <- 0.1 # percentage of the x-axis taken up by space between contigs
palette_space <- 4 # space between query contig colour and first ref colour


########
# MAIN #
########

# read the data
agp <- fread(agp_file, fill = TRUE, skip = 2)[!V5 %in% c("N", "U")]
raw_paf <- read_paf(paf_file)
paf_dt <- data.table(raw_paf)

# calculate spacing
padding <- get_padding(paf_dt[tp == "P" & nmatch >= min_nmatch])

# order the reference contigs
paf_dt[, tname := factor(tname, levels = gtools::mixedsort(unique(tname)))]
setkeyv(paf_dt, cols = sort_columns)

# generate continuous  reference coordinates
tpaf <- unique(paf_dt, by = "tname")
tpaf[, pad_tstart := shift(cumsum(tlen + padding[["t_padding"]]), 1, 0)]
tpaf[, shift_tstart := pad_tstart + (padding[["t_padding"]] / 2)]
tpaf[, pad_tend := shift_tstart + tlen]

# order the query contigs by their position in the AGP file
query_order <- agp[, V6]

query_paf <- paf_dt[qname %in% query_order & tp == "P" & nmatch >= min_nmatch]
subset_query_order <- query_order[query_order %in% query_paf[, qname]]

# Map query contigs onto a universal x-scale
query_paf[, qname := factor(qname, levels = subset_query_order)]
setkeyv(query_paf, cols = sort_columns)

qpaf <- unique(query_paf, by = "qname")
qpaf[, pad_qstart := shift(cumsum(qlen + padding[["q_padding"]]), 1, 0)]
qpaf[, shift_qstart := pad_qstart + (padding[["q_padding"]] / 2)]
qpaf[, pad_qend := shift_qstart + qlen]

# generate offsets for the alignment records
tstarts <- unique(tpaf[, .(tname, shift_tstart)])
qstarts <- unique(qpaf[, .(qname, shift_qstart)])

# adjust the alignment coordinates
paf_dt[,
  c(
    "adj_qstart",
    "adj_qend",
    "adj_tstart",
    "adj_tend"
  ) := adjust_coords(qname, qstart, qend, tname, tstart, tend),
  by = .(qname, qstart, qend, tname, tstart, tend)
]

# generate polygons. P is for primary alignments only
paf_polygons <- paf_dt[
  tp == "P" & nmatch >= min_nmatch,
  .(
    x = c(adj_tstart, adj_qstart, adj_qend, adj_tend),
    y = c(t_y, q_y, q_y, t_y),
    id = paste0("polygon", .GRP)
  ),
  by = .(qname, qstart, qend, tname, tstart, tend)
]

# set up plot
total_height <- (q_y - t_y) * 1.618
y_axis_space <- (total_height - (q_y - t_y)) / 2
middle_x <- tpaf[1, shift_tstart] + tpaf[.N, pad_tend] / 2

all_contig_names <- c(tpaf[, unique(tname)])
all_colours <- viridisLite::viridis(
  length(all_contig_names) + palette_space + 1
)
names(all_colours) <- c(
  "query",
  rep("blank", palette_space),
  all_contig_names
)

# Plot the ideogram with ribbons connecting the two sets of contigs
gp <- ggplot() +
  theme_void(base_family = "Lato", base_size = 12) +
  scale_fill_manual(
    values = all_colours, guide = "none"
  ) +
  scale_colour_manual(
    values = all_colours, guide = "none"
  ) +
  geom_polygon(
    data = paf_polygons,
    aes(
      x = x, y = y, group = id, fill = tname
    ), alpha = 0.5
  ) +
  geom_segment(
    data = tpaf,
    aes(
      x = shift_tstart,
      xend = pad_tend,
      colour = tname
    ),
    y = t_y,
    linewidth = 5,
    lineend = "butt"
  ) +
  geom_segment(
    data = qpaf,
    aes(
      x = shift_qstart,
      xend = pad_qend
    ),
    colour = all_colours[["query"]],
    y = q_y,
    linewidth = 5,
    lineend = "butt"
  ) +
  ylim(
    t_y - y_axis_space,
    q_y + y_axis_space
  )



gp + annotate(
  geom = "text",
  label = "Query contigs",
  x = middle_x,
  y = q_y + (y_axis_space / 2),
  hjust = 0.5,
  vjust = 0.5
) +
  annotate(
    geom = "text",
    label = "Reference contigs",
    x = middle_x,
    y = t_y - (y_axis_space / 2),
    hjust = 0.5,
    vjust = 0.5
  )

ggsave(plot_file,
  gp,
  width = 10,
  height = 7.5,
  units = "in",
  device = cairo_pdf
)
