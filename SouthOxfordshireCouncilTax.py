import requests
from bs4 import BeautifulSoup
import csv
import time

# 定义目标年份（2024/2025）
YEAR = '23'  # '23' 对应 2024/2025 年度

# 定义税级列表和对应的分数
bands = [
    {'code': 'A', 'fraction': '6/9'},
    {'code': 'B', 'fraction': '7/9'},
    {'code': 'C', 'fraction': '8/9'},
    {'code': 'D', 'fraction': '9/9'},
    {'code': 'E', 'fraction': '11/9'},
    {'code': 'F', 'fraction': '13/9'},
    {'code': 'G', 'fraction': '15/9'},
    {'code': 'H', 'fraction': '18/9'}
]

# 定义字段名
fieldnames = ['name', 'Council', 'Band A (6/9)', 'Band B (7/9)',
              'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)',
              'Band F (13/9)', 'Band G (15/9)', 'Band H (18/9)']

# 创建会话对象
session = requests.Session()

# 获取教区列表的页面 URL
form_url = 'https://data.southoxon.gov.uk/ccm/support/Main.jsp?MODULE=Calculator'

# 获取教区列表
response = session.get(form_url)
response.raise_for_status()

soup = BeautifulSoup(response.content, 'html.parser')

# 找到教区下拉列表
parish_select = soup.find('select', {'name': 'PARISH'})

# 提取教区代码和名称
parish_options = parish_select.find_all('option')
parish_list = []
for option in parish_options:
    code = option['value']
    name = option.text.strip()
    parish_list.append({'code': code, 'name': name})

print(f"共找到 {len(parish_list)} 个教区。")

# 打开 CSV 文件
with open('southoxon_council_tax_2024_2025.csv', 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # 遍历每个教区
    for index, parish in enumerate(parish_list):
        parish_code = parish['code']
        parish_name = parish['name']
        print(f"正在处理第 {index + 1}/{len(parish_list)} 个教区：{parish_name}")

        record = {'name': parish_name, 'Council': 'South Oxfordshire District Council'}

        # 遍历每个税级
        for band in bands:
            try:
                # 构造表单数据
                payload = {
                    'MODULE': 'Calculation',
                    'YEAR': YEAR,
                    'PARISH': parish_code,
                    'FACTOR': band['code'],
                    'Submit': 'Submit'
                }

                # 发送 POST 请求
                result_response = session.post('https://data.southoxon.gov.uk/ccm/support/Main.jsp?MODULE=Calculation', data=payload)
                result_response.raise_for_status()

                # 解析结果页面
                result_soup = BeautifulSoup(result_response.content, 'html.parser')

                # 查找 Total 金额
                total_label_div = result_soup.find('div', class_='celldiv', string='Total')
                if total_label_div:
                    amount_div = total_label_div.find_next_sibling('div', class_='celldiv')
                    total_amount = amount_div.text.strip()
                    # 去除金额中的符号和逗号
                    total_amount = total_amount.replace('£', '').replace(',', '').strip()
                    # 添加到记录中
                    field_name = f"Band {band['code']} ({band['fraction']})"
                    record[field_name] = total_amount
                else:
                    print(f"未找到 Total 信息，跳过 Band {band['code']}")
            except Exception as e:
                print(f"处理 Band {band['code']} 时发生错误：{e}")
                continue

            # 为了礼貌，添加延迟
            time.sleep(0.1)

        # 将记录写入 CSV 文件
        writer.writerow(record)

print("数据已成功保存到 southoxon_council_tax_2024_2025.csv 文件中。")