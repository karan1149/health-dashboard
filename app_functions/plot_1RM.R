plot_one_rep_max <- function(
    exercise_names, line_type, show_single_rep, highlight_best_lifts, weightlifting_data
) {
    # Default exercises if none are selected
    if (length(exercise_names) == 0) {
      exercise_names <- c("Chin Up", "Bench Press (Barbell)")
    }

    filtered_data <- dplyr::filter(
        weightlifting_data, exercise_name %in% exercise_names
        )

    calculate_past_30_days_max <- function(dates, one_rep_maxs) {
      sapply(seq_along(dates), function(i) {
        current_date <- dates[i]
        past_30_days <- current_date - 30
        past_data <- one_rep_maxs[dates <= current_date & dates > past_30_days]
        max(past_data, na.rm = TRUE)
      })
    }

    # Highlight best lifts within 30 days preceding each data point
    if (highlight_best_lifts) {
        filtered_data <- filtered_data %>%
                         arrange(exercise_name, date) %>%
                         group_by(exercise_name) %>%
                         mutate(past_30_days_max = calculate_past_30_days_max(date, one_rep_max)) %>%
                         mutate(is_best_lift = one_rep_max == past_30_days_max) %>%
                         select(-past_30_days_max) %>%
                         ungroup()
    } else {
        filtered_data <- filtered_data %>%
                         mutate(is_best_lift = FALSE)
    }
    
    plot <- ggplot(
      filtered_data,
      aes(
        x = date, y = one_rep_max, group = exercise_name, colour = exercise_name, 
        text = paste(
          "Date:", date, 
          "<br>Exercise:", exercise_name,
          "<br>Estimated 1RM:", round(one_rep_max)
        )
      )
    ) +
    geom_point(
      size = 2,
      aes(alpha = if (highlight_best_lifts) if_else(is_best_lift, 0.5, 0.05) else 0.2)
    ) +
    ylab("Estimated One-Rep-Max (lbs)") +
    scale_color_manual(
      values = c("#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02")
    ) +
    scale_alpha(range = c(0.05, 0.5)) +
    scale_x_date(
      name = "Date",
      date_minor_breaks = "1 month",
      date_labels =  "%b %Y"
    ) +
    theme_minimal() +
    guides(
      alpha = guide_legend(title = NULL), 
      color = guide_legend(title = NULL)
    )

    if (line_type == "cummax") {
      plot <- plot + geom_line(aes(y = cummax_one_rep_max), size = 1)
    } else if (line_type == "rolling") {
      plot <- plot + geom_line(aes(y = rolling_90d_max), size = 1)
    }
    
    if (show_single_rep) {
      plot <- plot +
          geom_point(
              data = dplyr::filter(filtered_data, reps == 1), 
              shape = 18, # Diamond
              size = 3,
              alpha = 0.75
          )
    }

    # Make adjustments for translating ggplot to plotly
    plot <- ggplotly(plot, tooltip = "text") #%>%
      #layout(
      #  yaxis = list(title = 'Estimated One-Rep-Max (lbs)'),
      #  xaxis = list(
      #    title = 'Date',
      #    tickformat = '%b %Y',
      #    dtick = "M1"  # Monthly ticks
      #  ),
      #  colorway = c("#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02")
      #) #%>%
      #style(
      #  hoverlabel = list(bgcolor = "white", font = list(family = "Arial", size = 12)),
      #  margin = list(l = 60, r = 10, b = 50, t = 25, pad = 4)
      #)

    return(plot)
}