#!/bin/bash
ARGS=1
E_BADARGS=65
TEM_FILE="/tmp/dict.tmp" #缓存词义

if [ $# -ne "$ARGS" ]
then
	echo "Usage:`basename $0` word"
	exit $E_BADARGS
fi

# 抓取页面，删除html代码，空行等，只留下想要的内容
curl -s 'http://dict.youdao.com/search?q='$1'' \
	| awk 'BEGIN{i=0;e=0;j=0;} { \
			if(j!=1 && /phrsListTab/){i++;} \
			if(i==1  && !/errorreport/){print $0; if(/<\/ul>/){i=0;}} \
			if(i==0 && /error-typo/){e++;} \
			if(e==1){print $0; if(/<\/div>/){e=0;j=1}} \
		}' \
	| sed 's/<[^>]*>//g' \
	| sed 's/&nbsp;//g' \
	| sed 's/&rarr;//g' \
	| sed 's/^\s*//g' \
	| sed '/^$/d' \
> $TEM_FILE

# 处理输出
is_head=true # 当前行是否属于“头部”
left_b=false #left bracket
right_b=false #right bracket
jiucuo=false

while read line
do
	let line_num++	#行号

	num_flag=`echo "$line" | awk '/[0-9]+\.$/'`
	if [ "$num_flag" != "" ]; then ## 遇见'数字+点'开头的行
		is_head=false # 第一次遇见数字行  将头部标示设置为false
	fi

	eng_amr=$(echo "$line" | awk '/^(英|美)$/')
	pron=$(echo "$line" | awk '/^\[.*\]$/')	#匹配到读音音标
	word=$(echo "$line" | awk "/^$1$/")		#匹配当前查询单词
	lb=$(echo "$line" | egrep '^\(')
	jc=$(echo "$line" | egrep '^纠错$')	# 多出“纠错”行，进行标记
	if [ "$jc" != "" ]; then
		jiucuo=true
	fi
	if [ "$lb" != "" ]; then	#匹配左括号所在行
		left_b=true
	fi
	rb=$(echo "$line" | egrep '^\)')
	if [ "$rb" != "" ]; then	#匹配有括号所在行
		right_b=true
	fi

# 对输出结果格式处理
	if $is_head ; then
		if ((line_num == 1)); then	#第一行
			echo -e "\033[33;1m $line\033[0m"
		elif [ "$eng_amr" != "" ]; then
			echo -en "\033[33;1m $line \033[0m"
		elif [ "$pron" != "" ]; then	#英式发音和美式发音的音标
			echo -e "\033[33;1m $line\033[0m"
		elif [ "$word" != "" ]; then	#当前查询的单词所在行
			echo -en "\033[32;1m $line \033[0m"
		#elif [ "$left_b" == true -a "$right_b" == false ]; then	#在左右括号内的行
		elif $left_b && !($right_b); then	#在左右括号内的行
			echo -en "\033[32;1m $line\033[0m"
		elif $right_b ; then
			echo -e "\033[32;1m $line\033[0m"
		elif $jiucuo; then	# 出现“纠错”行，则不打印该行，并将该标记重置为false
			jiucuo=false
		else
			echo -e "\033[32;1m $line\033[0m"
		fi
	else
		break
	fi
done < $TEM_FILE
echo -e "\033[31;1m http://dict.youdao.com/search?q=$1\033[0m"
# 删除缓存文件
rm -rf $TEM_FILE
exit 0
