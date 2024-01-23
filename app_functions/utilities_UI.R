# Define a function to create HTML labels with tooltips
create_label_with_tooltip <- function(label_text, tooltip_id) {
  HTML(paste0(
    '<span>', 
    label_text, 
    ' <i id="', tooltip_id, 
    '" class="fas fa-info-circle text-muted" style="font-size: 70%; vertical-align: super;"></i></span>'
  ))
}