library(tabulizer)
library(dplyr)

# 指定 PDF 文件路径
pdf_file <- "./wodc-council-tax-charges-2024-to-2025.pdf"

# 提取所有页面的表格
tables <- extract_tables(pdf_file, pages = "all", guess = TRUE)

# 初始化字段名
fieldnames <- c('name', 'Council', 'Band A (6/9)', 'Band B (7/9)',
                'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)',
                'Band F (13/9)', 'Band G (15/9)', 'Band H (18/9)')

# 初始化空的数据框
final_df <- data.frame(matrix(ncol = length(fieldnames), nrow = 0))
colnames(final_df) <- fieldnames

# 假设 'Council' 列的值为 'West Oxfordshire District Council'
council_name <- 'West Oxfordshire District Council'

# 处理提取的表格
for (i in seq_along(tables)) {
  table <- tables[[i]]
  # 将表格转换为数据框
  df <- as.data.frame(table, stringsAsFactors = FALSE)

  # 跳过空表格
  if (nrow(df) == 0) {
    next
  }

  # 将第一行设置为列名
  colnames(df) <- df[1, ]
  df <- df[-1, ]  # 删除第一行

  # 去除列名和数据中的空格
  colnames(df) <- trimws(colnames(df))
  df <- df %>%
    mutate(across(everything(), ~ trimws(.)))

  # 重命名 'Parish/Town' 列为 'name'
  if ('Parish/Town' %in% colnames(df)) {
    df <- df %>%
      rename(name = 'Parish/Town')
  } else if ('Parish' %in% colnames(df)) {
    df <- df %>%
      rename(name = 'Parish')
  } else {
    # 如果没有找到名称列，跳过此表格
    next
  }

  # 添加 'Council' 列
  df$Council <- council_name

  # 重命名 Band 列，使其与指定的列名匹配
  band_columns <- colnames(df)[grepl("^Band", colnames(df))]

  # 创建一个映射，将原始列名映射到新的列名
  band_mapping <- c(
    'Band A' = 'Band A (6/9)',
    'Band B' = 'Band B (7/9)',
    'Band C' = 'Band C (8/9)',
    'Band D' = 'Band D (9/9)',
    'Band E' = 'Band E (11/9)',
    'Band F' = 'Band F (13/9)',
    'Band G' = 'Band G (15/9)',
    'Band H' = 'Band H (18/9)'
  )

  # 根据映射重命名列
  df <- df %>%
    rename_at(vars(band_columns), ~ band_mapping[.])

  # 选择并排列列，确保与指定的字段名一致
  df <- df %>%
    select(all_of(fieldnames))

  # 将处理好的数据添加到最终的数据框
  final_df <- bind_rows(final_df, df)
}

# 保存为 CSV 文件
output_csv <- "./wodc_council_tax_data.csv"
write.csv(final_df, output_csv, row.names = FALSE)

cat("数据已成功保存到", output_csv, "\n")