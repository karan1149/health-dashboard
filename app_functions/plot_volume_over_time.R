plot_volume_over_time <- function(data, rollavg_length_volume = 0.005, exclude_zeros = TRUE){
    # Possibly exclude zeros
    if (exclude_zeros) {
      data <- data %>%
        filter(one_rep_max > 0)
    }

    plot <- data %>%
      mutate(
        exp_moving_avg = map_dbl(
          date,
          function(d) rolling_weighted_average(
            one_rep_max,
            date,
            d,
            epsilon = rollavg_length_volume
          )
        )
      ) %>%
      ggplot(aes(
        x = date, 
        y = one_rep_max
        )) +
      geom_point(alpha = 1 / 3, colour = "#1b9e77") +
      geom_line(
        aes(x = date, y = exp_moving_avg),
        colour = "#1b9e77",
        size = 1
        ) +
      scale_fill_manual(
        values = c("#1b9e77", "#d95f02", "#7570b3", "#e7298a")
      ) +
      scale_x_date(
        date_minor_breaks = "1 month",
        date_labels =  "%b %Y",
        expand = c(0,0)
        ) +
      scale_y_continuous(
        expand = c(0, 0),
        limits = c(0, NA)
      ) +

      theme_minimal() +
      theme(
        axis.text.x = element_text(size = 12, angle = 90, vjust = 0.5, hjust = 1),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_blank(),
        axis.title.y = element_text(size = 14),
        plot.title = element_text(size = 24),
        legend.title = element_blank()
      )

    return(plot)
  } 