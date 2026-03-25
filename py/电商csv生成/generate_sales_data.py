#!/usr/bin/env python3
"""
电商销售数据生成器
用法: python generate_sales_data.py --rows 10000 --output sales_data.csv
"""

import csv
import random
import argparse
from datetime import datetime, timedelta

# ── 数据字典 ──────────────────────────────────────────────
CATEGORIES = {
    "手机数码": ["iPhone 15 Pro", "华为 Mate 60", "小米 14", "OPPO Find X7", "三星 S24",
                "AirPods Pro", "索尼耳机 WH-1000XM5", "iPad Air", "华为平板 MatePad"],
    "服装鞋帽": ["耐克运动鞋", "阿迪达斯T恤", "优衣库羽绒服", "李宁卫衣", "HM牛仔裤",
                "安踏运动裤", "波司登羽绒服", "New Balance跑鞋", "北面冲锋衣"],
    "美妆护肤": ["兰蔻粉底液", "SK-II神仙水", "雅诗兰黛眼霜", "完美日记口红",
                "资生堂防晒霜", "欧莱雅洗发水", "海蓝之谜面霜", "修丽可精华"],
    "家居用品": ["小米扫地机器人", "戴森吸尘器", "九阳豆浆机", "美的空气炸锅",
                "苏泊尔电饭锅", "飞利浦电动牙刷", "松下洗碗机", "格力空调"],
    "食品生鲜": ["东北大米 5kg", "进口车厘子 1kg", "有机牛奶 12盒", "新疆红枣 500g",
                "挪威三文鱼 500g", "云南咖啡豆 250g", "西班牙火腿", "澳洲牛排 300g"],
    "运动户外": ["迪卡侬帐篷", "探路者登山包", "GARMIN手表", "骑行头盔",
                "瑜伽垫", "哑铃套装", "跑步机", "钓鱼竿套装"],
    "图书文教": ["Python编程入门", "三体全集", "英语四级词汇", "高考数学真题",
                "艺术史", "投资理财入门", "心理学与生活", "围棋入门"],
    "母婴玩具": ["乐高积木", "芭比娃娃", "婴儿推车", "奶粉 900g",
                "纸尿裤 80片", "儿童绘本套装", "益智玩具", "婴儿辅食机"],
}

PROVINCES = ["北京", "上海", "广东", "浙江", "江苏", "四川", "湖北", "河南",
             "山东", "福建", "湖南", "河北", "陕西", "重庆", "天津"]

CHANNELS = ["天猫", "京东", "拼多多", "抖音小店", "快手小店", "小红书", "官网自营", "微信小程序"]

PAYMENT_METHODS = ["支付宝", "微信支付", "银行卡", "花呗", "京东白条", "云闪付"]

STATUS_WEIGHTS = {
    "已完成": 65,
    "已发货": 15,
    "待发货": 8,
    "已退款": 7,
    "退款中": 3,
    "已取消": 2,
}

MEMBER_LEVELS = ["普通会员", "银牌会员", "金牌会员", "钻石会员", "超级会员"]

# ── 工具函数 ──────────────────────────────────────────────

def random_date(start_year=2023, end_year=2024):
    start = datetime(start_year, 1, 1)
    end = datetime(end_year, 12, 31)
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days),
                             hours=random.randint(0, 23),
                             minutes=random.randint(0, 59))

def weighted_choice(weight_dict):
    items = list(weight_dict.keys())
    weights = list(weight_dict.values())
    return random.choices(items, weights=weights, k=1)[0]

def generate_order_id(index):
    return f"ORD{random.randint(100,999)}{index:07d}"

def generate_user_id():
    return f"U{random.randint(10000000, 99999999)}"

def generate_row(index):
    category = random.choice(list(CATEGORIES.keys()))
    product = random.choice(CATEGORIES[category])
    quantity = random.choices([1, 2, 3, 4, 5], weights=[50, 25, 12, 8, 5])[0]

    # 各品类价格区间
    price_ranges = {
        "手机数码":  (199,  8999),
        "服装鞋帽":  (29,   1999),
        "美妆护肤":  (39,   2999),
        "家居用品":  (49,   5999),
        "食品生鲜":  (9,    599),
        "运动户外":  (29,   3999),
        "图书文教":  (9,    199),
        "母婴玩具":  (19,   2999),
    }
    lo, hi = price_ranges[category]
    unit_price = round(random.uniform(lo, hi), 2)
    total_price = round(unit_price * quantity, 2)

    discount_rate = random.choices(
        [0, 0.05, 0.10, 0.15, 0.20, 0.30],
        weights=[30, 20, 20, 15, 10, 5]
    )[0]
    discount_amount = round(total_price * discount_rate, 2)
    actual_payment = round(total_price - discount_amount, 2)

    order_date = random_date()
    status = weighted_choice(STATUS_WEIGHTS)

    # 退款金额
    refund_amount = actual_payment if status in ("已退款", "退款中") else 0.0

    province = random.choice(PROVINCES)
    rating = random.choices([None, 1, 2, 3, 4, 5],
                            weights=[20, 2, 3, 10, 25, 40])[0]

    # ── 日期维度字段 ──
    quarter = (order_date.month - 1) // 3 + 1
    week_cn = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    hour = order_date.hour
    if 6 <= hour < 12:
        time_period = "上午"
    elif 12 <= hour < 14:
        time_period = "午间"
    elif 14 <= hour < 18:
        time_period = "下午"
    elif 18 <= hour < 22:
        time_period = "晚间"
    else:
        time_period = "深夜"

    return {
        "订单ID":       generate_order_id(index),
        "用户ID":       generate_user_id(),
        "会员等级":     random.choice(MEMBER_LEVELS),
        "下单时间":     order_date.strftime("%Y-%m-%d %H:%M:%S"),
        "日期":         order_date.strftime("%Y-%m-%d"),
        "年份":         order_date.year,
        "月份":         order_date.month,
        "季度":         f"Q{quarter}",
        "星期":         week_cn[order_date.weekday()],
        "时段":         time_period,
        "商品分类":     category,
        "商品名称":     product,
        "数量":         quantity,
        "单价":         unit_price,
        "原始总价":     total_price,
        "折扣金额":     discount_amount,
        "实付金额":     actual_payment,
        "退款金额":     refund_amount,
        "支付方式":     random.choice(PAYMENT_METHODS),
        "销售渠道":     random.choice(CHANNELS),
        "省份":         province,
        "订单状态":     status,
        "用户评分":     rating if rating else "",
        "是否首单":     random.choices(["是", "否"], weights=[15, 85])[0],
    }

# ── 主程序 ────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="电商销售数据生成器")
    parser.add_argument("--rows",   type=int,   default=1000,              help="生成行数 (默认 1000)")
    parser.add_argument("--output", type=str,   default="sales_data.csv",  help="输出文件名")
    args = parser.parse_args()

    print(f"⏳ 正在生成 {args.rows:,} 条数据...")

    fieldnames = [
        "订单ID", "用户ID", "会员等级",
        "下单时间", "日期", "年份", "月份", "季度", "星期", "时段",
        "商品分类", "商品名称", "数量", "单价",
        "原始总价", "折扣金额", "实付金额", "退款金额",
        "支付方式", "销售渠道", "省份", "订单状态",
        "用户评分", "是否首单",
    ]

    with open(args.output, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for i in range(1, args.rows + 1):
            writer.writerow(generate_row(i))
            if i % 10000 == 0:
                print(f"  已生成 {i:,} 条...")

    print(f"✅ 完成！文件已保存至: {args.output}")
    print(f"   共 {args.rows:,} 条记录，字段数: {len(fieldnames)}")

if __name__ == "__main__":
    main()