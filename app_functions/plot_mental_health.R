# Function to calculate the exponential moving average
weighted_average <- function(xs, weights) {
    # returns weighted average for given weights
    sum(xs*weights) / sum(weights)
}


rolling_weighted_average <- function(xs, date, target_date, epsilon = 0.0035) {
    # returns weights for exponential moving average
    time_diff <- as.numeric(abs(difftime(target_date, date, units = "day")))
    weights <- exp(-epsilon*time_diff)
    
    weighted_average(xs, weights)
}

calculate_exp_moving_avg <- function(data, epsilon) {
  data %>%
    mutate(
      exp_moving_avg = map_dbl(
        date,
        function(d) rolling_weighted_average(value, date, d, epsilon = epsilon)
      )
    )
}

# Function to create well-being plot
plot_mental_health <- function(
    data, rollavg_length, 
    metric_names#, include_partial_data
    ) {
  # Handle different metric selections
  if (length(metric_names) == 0) {
    metric_names <- c("Mental Health")
  }
  
  # Filter and calculate exponential moving average
  filtered_data <- data %>%
    filter(metric %in% metric_names) %>%
    drop_na(value) %>%
    mutate(positive_value = value > 0) %>%
    group_by(metric) %>%
    calculate_exp_moving_avg(epsilon = rollavg_length) %>%
    ungroup()

  # Base plot
  plot <- ggplot(
    filtered_data, 
    aes(
      x = date, 
      y = value, 
      text = paste(
        "Date:", date, 
        "<br>Value:", round(value), 
        ifelse(is.na(note) | note == "", "", paste("<br>Note:", note))
        )
      )
    )

  # Add elements based on the number of metrics
  if (length(metric_names) == 1) {
    plot <- plot +
      geom_hline(yintercept = 0, colour = "#636363") +
      geom_point(
        aes(fill = positive_value, colour = positive_value), 
        alpha = 1/5
        )
      
    plot <- add_single_metric_elements(plot)
  } else {
    plot <- plot +
      geom_hline(yintercept = 0, colour = "#636363")

    plot <- add_multi_metric_elements(plot, metric_names)
  }

  #if (include_partial_data) {
  #  plot <- plot +
  #      geom_point(aes(y=value_partial), alpha=1/10)
  #}

  # Common plot elements
  plot <- plot +
    scale_x_date(date_minor_breaks = "1 month", date_labels = "%b %Y", expand = c(0, 0)) +
    scale_y_continuous(lim = c(-(100+1), 100+1), breaks = seq(-100, 100, 25), expand = c(0, 0)) +
    theme_minimal_base()

  return(plot)
}

# Additional functions to add plot elements
add_single_metric_elements <- function(plot) {
    plot +
        geom_line(aes(y = exp_moving_avg), size = 1, colour = "#7570b3", linetype = "solid") +
        scale_colour_manual(values = c("#d95f02", "#1b9e77")) +
        scale_fill_manual(values = c("#d95f02", "#1b9e77")) +
        geom_ribbon(aes(ymin = 0, ymax = pmax(exp_moving_avg, 0)), fill = "#1b9e77", colour = "#1b9e77", alpha = 1/3) +
        geom_ribbon(aes(ymin = pmin(exp_moving_avg, 0), ymax = 0), fill = "#d95f02", colour = "#d95f02", alpha = 1/3) +
        theme(legend.position = "none") +
        labs(colour = NULL)
}

add_multi_metric_elements <- function(plot, metric_names) {
    colors <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02", "#a6761d", "#666666")

    # Assuming 'metric' is a column in your data
    metric_levels <- levels(as.factor(plot$data$metric))

    # Function to prettyify metric names
    pretty_metric_names <- function(x) {
        sapply(x, function(y) toTitleCase(gsub("_", " ", y)))
    }

    # Apply pretty_metric_names to the actual metric names in your data
    pretty_metric_levels <- pretty_metric_names(metric_levels)

    plot +
        geom_point(aes(colour = metric), alpha = 1/(5*length(metric_names))) +
        geom_line(aes(y = exp_moving_avg, colour = metric, group = metric), size = 1, linetype = "solid") +
        scale_colour_manual(values = colors, labels = pretty_metric_levels) +
        labs(colour = "Metric")
}

theme_minimal_base <- function() {
  theme_minimal() +
  theme(
    axis.text.x = element_text(size = 12, angle = 0, vjust = 0.5, hjust = 1),
    axis.text.y = element_text(size = 12),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    plot.title = element_text(size = 20)
  )
}
