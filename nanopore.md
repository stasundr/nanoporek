# Инструкция для обработки данных секвенирования Oxford Nanopore

Задача по обработки данных секвенирования Oxford Nanopore разделана на два этапа:

1.  Получение файла в fastq-формате, определение качества ридов и необходимый их процессинг.
2.  Картирование и выравнивание ридов образца на референсный геном.

## Анализ качества ридов

Все используемые файлы можно нати на сайте [NCBI](https://www.ncbi.nlm.nih.gov/sra/) в базе данных SRA. Из всех представленных в базе образцов с момощью фильтра отбирались только данные, секвенированные на Oxford Nanopore для Homo sapiens и Escherichia coli. На странице SRA после поиска образцов, перейдя по ссылке "Send to" в правом верхнем углу страницы, можно скачать Summary-file для человеческих и бактериальных образцов. Данный файл содержит подробную информацию об образце и эксперементе в котором он использовался. Таким образом, на основе Summary-file мы сформировали тестируемую выборку, в которую вошли образцы с разными показателями качества.

Отобранные образцы были скачены с помощью программы fastq-dump:

```sh
fastq-dump —defline-qual '+' —split-files myfile.fastq
```

### Самописные программы для анализа качества ридов

В fastq-файле на каждый рид образца отводится по 4 строки (1- название рида; 2- секвенированная последовательность; 3- знак "+"; 4- качество каждого нуклеотида в ASCII). Для данных Oxford Nanopore не сформирована таблица перевода ASCII в значения Phred Score.
Для этого была написана программа (programs/quality), которая на вход принемает анализируемый файл, а на выходе выдает таблицу, в которой отражены все символы ASCII и их перевод в Phred Score. В результате тестирований не удалось получить одну фиксированную шкалу перевода ASCII в Phred Score.

Для построения графика, который отражает качество каждого нуклеотида был написана программа на JavaScript - change-quality.js. На вход программа принимает fastq-файл:

```sh
node change-quality.js
```

Для анализа длины ридов был написан R-скрипт - read_quality_trough_length.r. На вход программа принемает fastq-файл, а выдает файл Rplot. Rplot - график на котором х - длина рида (промежуток от 0 до 500, от 500 до 2000 и тд), а по оси y - количество ридов в определенном промежутке. Команда для запуска скрипта:

```sh
Rscript read_quality_trough_length.r myfile.fastq
```

### Готовые программы для визуализации качества ридов в образце

В дальнейшей работе тестировались несколько программ для отбора наиболее подходящей для визуализации качества образцов:
NanoPlot, NanoQC, fastx-length, length_plot, fastx-rlength, NanoStat, pauvre, ToulligQC. Наиболее подходящие программы из списка, которые активно использовались в работе - NanoPlot, NanoQC, pauvre.

[NanoPlot](https://github.com/wdecoster/NanoPlot) cтроит ряд графиков, которые отражают соотношение длины рида и их количества, а также распределение качества ридов. На вход подем не модифицированные fastq-файл, -o - папка, в которую сохраняем результат, -p - префикс, который добавляется к сгенерированным выходным файлам, --N50 добавляет на графике линию N50.
Для запуска:

```sh
NanoPlot --fastq myfile.fastq -o NanoPlot_result/ -p myfile_1.fastq --N50
```

[pauvre](https://github.com/conchoecia/pauvre) программа аналогичная NanoPlot
Для запуска:

```sh
pauvre marginplot -f ~/myfile.fastq
```

[NanoQC](https://github.com/wdecoster/nanoQC). На вход необходимо подавать заархивированный файл - myfile.gz. -o - папка, в которую сохраняем результат. На выходе выдает график с качеством ридов (секвенограмма), который позволяет понять сколько нуклеотидов в риде плохого качества в начале и конце.
Для запуска:

```sh
nanoQC -o ~/nanoQC_result/ myfile.fastq.gz
```

Все перечисленные программы позволяют понять, какая дальнейшая обработка требуется образцу.

Для перехода в фрмат программы nanoQC удобно использовать следующие команды:

```shg
gzip -c file.txt > file.txt.gz
gunzip -c example.gz > decompressed-file
```

## Процессинг ридов

[NanoFilt](https://github.com/wdecoster/nanofilt)

Главный недостаток программы - невозможность отфильтровать риды и получить выборку с минимальным качеством ридов в образце. Для этого был создан самописный скрипт - programs/residual.py

Для проверки и выбора наиболее подходящей программы для картирования и выравнивания генома был выбран один fastq-файл с генетическими данными человека (SRR5951596). Сперва файл подали на вход программам nanoQC и NanoPlot для визуализации начальных данных. nanoQC показала плохое качество первых и последних 25 нуклеотидов в каждом риде, которое необходимо будет в дальнейщем скорректировать. Для картирования ридов, cеквеннированых на oxford nanopore, они должны быть не короче 1000 нуклеотидов.
Перечисленные задачи выполнялись с помощью программы NanoFilt

```sh
cat SRR5951596.fastq | NanoFilt --headcrop 25 --tailcrop 25 > trimmed-reads-25-SRR5951596.fastq
```

Полученный файл визуализировали программой NanoPlot, которая показала распределение ридов в образце по длинне и качеству. Для картирования ридов nanopore риды должны быть не короче 1000 нуклеотидов. Для того чтобы понять насколько качество рида влияет на картирование и выравнивание, образец необходимо разделить по качеству прочтения ридов (пороговая величина качества - 10). NanoFilt может отбирать по качеству риды только выше обозначенного значения:

```sh
cat trimmed-reads-25-SRR5951596.fastq | NanoFilt -q 10 -l 1000 > trimmed-reads-25n-q10-l1000-SRR5951596.fastq
```

Чтобы получить выборку с качеством ридов меньше 10, используем свмописный скрипт - residual.py (первый аргумент - начальный fastq-файл, второй аргумент - часть файла, которую мы хотим исключить, третий аргумент - новый файл, с качеством < 10, который хотим получить)

```sh
programs/residual.py files/SRR5951596.fastq files/trimmed-reads-25n-q10-l1000-SRR5951596.fastq  trimmed-reads-25n-minq10-l1000-SRR5951596.fastq
```

Таким образом, у нас есть два файла ( качество ридов > 10 и < 10), которые необходимо картировать на референсный геном человека (build38).
Наиболее подходящая прграмма для этой задачи - ngmlr. Действия при запуске ngmlr:

```sh
cd programs/
ngmlr-0.2.7/ngmlr -t 2 -r /storage/nanopore/references/hg38.fa -q /storage/nanopore/files/trimmed-reads-25n-q10-l1000-SRR5951596.fastq -o /storage/nanopore/files/trimmed-reads-25n-q10-l1000-SRR5951596.sam -x ont
```

На выходе получаем sam-файл, который можно перевести в формат bam программой samtools:

```sh
samtools view files/trimmed-reads-25n-q10-l1000-SRR5951596.sam -b -o files/trimmed-reads-25n-q10-l1000-SRR5951596.bam
```

Для более быстрой работы программы рекомендуется ее запуск в фоновом режиме:

```sh
ngmlr-0.2.7/ngmlr -t 2 -r /storage/nanopore/references/hg38.fa -q /storage/nanopore/files/trimmed-reads-25n-q10-l1000-SRR5951596.fastq -o /storage/nanopore/files/trimmed-reads-25n-q10-l1000-SRR5951596.sam -x ont &>running.log &
```

Чтобы посмотреть номер задачи и иметь возможность ее остановить, используем команды:

```sh
top
kill
```

Точно такие же действия проводим и с файлом, качество ридов которого меньше 10. По итогу работы программ, на экране или в файле log можно увидеть краткую статистику картирования ридов. В нашем случае, в файле с качество ридов >10 успешно картировались 95,84% ридов, а в файле с качество ридов < 10 - 27,9%. Данный эксперимент подтверждает необходимость фильтрации ридов по качеству до их выравнивания на референсный геном.

После получения bam-файла работаем в программе Samtools
Сортировка ридов:

```sh
samtools sort files/trimmed-reads-25n-q10-l1000-SRR5951596.bam - o sort-files/trimmed-reads-25n-q10-l1000-SRR5951596.bam
```

Индексируем отсортированные риды:

```sh
samtools index sort-trimmed-reads-25n-q10-l1000-SRR5951596.bam
```

Проверяем покрытие каждого нуклеотида командой:

```sh
samtools depth -a files/sort-trimmed-reads-Ecoli-ERR1676720.bam > files/sort-trimmed-reads-Ecoli-ERR1676720-depth
```

Для нахждения максимальго покрытия используем сортировку:

```sh
sort -k3,3nr files/sort-trimmed-reads-Ecoli-ERR1676720-depth > files/sort-trimmed-reads-Ecoli-ERR1676720-depth-list
```

Чтобы создать vcf-файл с snp образца, используем команду:

```sh
samtools mpileup -uf references/GCF_000005845.2_ASM584v2_genomic.fna files/trimmed-reads-40-100-ERR701174-sort.bam | bcftools call -mv -Ov --ploidy 1 -o Ecoli-ERR701174-snp.vcf &
```

Команда для просмотра сатистики bam-файла:

```sh
samtools stats trimmed-reads-Ecoli-ERR1676720.bam | less
```

получаем следующие показатели:
reads mapped: 2826
bases mapped: 17607626

Подсчет глубины прочтения для одного нуклеотида
считает строки в референсе (58022) и умножаем на количество букв в строке(80), учитывая что последняя строка 52 буквы и есть заголовок(1). Количество букв в референсе равно 4641652=(58022-2)\*80+52
17607626/4641652=3,79
207410371/4808913=43

другое выравнивание

##Сравнение работы различных выравнивателей на примере образца SRR8365075 (salmonella)

1. Выравниватель ngmlr-0.2.7/ngmlr использовался также как и в вышеприведенном примере.
   На выходе получаем файл trimmed-reads-n14-salmonella-SRR8365075.bam (без упоминания выравнивателя в названии)

   Статистика выравнивания:
   reads mapped: 29827
   reads unmapped: 1678
   total length: 216405990
   bases mapped: 207410371
   average quality: 12.5

2. Выравниватель minimaper2
   Команда для запуска:

```sh
	./programs/minimap2/minimap2 -ax map-ont references/ref-Ecoli-K12.fna files/Ecoli/Katya/trimmed-reads-35-30n-q8-l1000-ERR1309542.fastq > files/Ecoli/Katya/trimmed-reads-35-30n-q8-l1000-ERR1309542-minimap2.sam
```

    Выравнивание прошло, но bam-файл сформировался неправильно (проблемы с заголовком). Нельзя посмотреть статистику выравнивания и вообще использовать bam-файл в дальнейшей обработке образца. Поэтому в данном случае мы используем образеуц Ecoli для сравнения данного выравнивателя с ngmlr

3. Вырвниватель minialign
   после вызова программы samtools stats получаем статистику выравнивания:
   reads mapped: 30552
   reads unmapped: 955
   total length: 216413565
   bases mapped: 212260330
   average quality: 255.0

```sh
    programs/ocxtal/minialign/minialign -t4 -xont.r9.1d /storage/nanopore/references/salmonella-Bareilly.fna files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075.fastq > files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075-minialign.sam
```

4. Выравнватель nanoblaster
   Команда для запуска:

```sh
programs/NanoBLASTer/nano_src/nanoblaster -r references/salmonella-Bareilly.fna -i files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075.fa -o files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075-nanoblast.sam
```

    Вся статистика - 0

##Сборка генома

1. Canu
   Команда для запуска:

```sh
	canu -d files/Salmonella -p files/Salmonella/salmonella-test-canu  -nanopore-raw files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075.fa.gz -genomeSize=179.2m
```

    Програма до конца не работает, не хватает технических мощностей

2.      miniasm -f files/Ecoli/Katya/trimmed-reads-35-30n-q8-l1000-ERR1309542.fastq files/Ecoli/Katya/trimmed-reads-35-30n-q8-l1000-ERR1309542.fastq-minimap2.paf.gz > miniasm-test

    Не работает, возможно требуется более качественный файл на вход

##Коллинг снипов

Перечисленные программы имеют много функций, но в данном случае нам интересен только коллинг снипов

1. medaka
   Команда для запуска:

```sh
	medaka_variant - f references/salmonella-Bareilly.fna -b files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075-sort.bam -m r941_flip213
```

2. nanopolish
   Команда для запуска:

```sh
	nanopolish variants --snps --reads files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075.fa --bam files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075.bam  -p 1 -w 1 --genome references/salmonella-Bareilly.fna > trimmed-reads-n14-salmonella-SRR8365075-nanopolish-snp.snp
```

3. clairvoyante.py
   Команда для запуска:

```sh
 	clairvoyante.py callVarBam --ref_fn references/salmonella-Bareilly.fna --bam_fn files/Salmonella/trimmed-reads-n14-salmonella-SRR8365075-sort.bam
```

##Для работы с FAST5 файлами

База данных, где можно скачать файлы (https://datamed.ucsd.edu/search.php?searchtype=data&query=hdf5&offset=1&rowsPerPage=20&sort=relevance)

Источник данных - https://trace.ncbi.nlm.nih.gov/Traces/sra/?run=SRR9211298 (Bacteremia Staphylococcus)

После скачивания сырых данных (fast5-файла) можно сформировать нуклеотидные последовательности несколькими программами:

1. nanopolish:

```sh
	nanopolish extract -q -o  53_58_nanopolish barcode07_53_58
```

На вход подаем файл формата fast5, а на выходе получаем готовый fastq-файл. Действует для случая, когда хотим по отдельности обработать риды. Для одновременной обработки работает команда:

```sh
nanopolish extract --type 2d -q flowcell_17/downloads/ flowcell_18/downloads/ -o from_fast5_nanopolosh
```

fastq-файл весит 1.3G

Проверяем качество готового fastq-файла:

```sh
	programs/quality1.py files/FAST5/from_fast5
```

Далее проводим обработку полученного fastq-файла по вышепрописанной инструкции (визуализация качества ридов и их процессинг).
Выравнивание осуществляли двумя способами: через ngmlr и minialign
Ниже приведен алгоритм для ngml

```sh

nanoQC -o ~/nanoQC_result/ FAST5/53_58_nanopolish.fastq &

cat 53_58_nanopolish.fastq | NanoFilt --headcrop 20 --tailcrop 20 -q 10 -l 1000 > trimmed-reads-20-5358nanopolish.fastq &
programs/ocxtal/minialign/minialign -t2 -xont.r9.1d /storage/nanopore/references/GCA_000185885.1_ASM18588v1_genomic.fna files/FAST5/trimmed-reads-20-5358nanopolish.fastq > files/FAST5/trimmed-reads-20-5358nanopolish-minialign.sam

programs/ngmlr-0.2.7/ngmlr -t 2 -r /storage/nanopore/references/GCA_000185885.1_ASM18588v1_genomic.fna -q /storage/nanopore/files/FAST5/trimmed-reads-20-5358nanopolish.fastq -o /storage/nanopore/files/FAST5/trimmed-reads-20-5358nanopolish-ngmlr.sam -x ont &

 samtools view files/FAST5/trimmed-reads-20-5358nanopolish-ngmlr.sam -b -o files/FAST5/trimmed-reads-20-5358nanopolish.bam

 samtools sort files/FAST5/trimmed-reads-20-5358nanopolish.bam -o files/FAST5/trimmed-reads-20-5358nanopolish.bam

 samtools index files/FAST5/trimmed-reads-20-5358nanopolish.bam

 samtools depth  files/FAST5/trimmed-reads-20-5358nanopolish.bam | sort -k3,3nr > files/FAST5/trimmed-reads-20-5358nanopolish-depth

 samtools mpileup -uf references/GCA_000185885.1_ASM18588v1_genomic.fna files/FAST5/trimmed-reads-20-5358nanopolish-ngmlr.bam  | bcftools call -mv -Ov --ploidy 1 -o files/FAST5/trimmed-reads-20-5358nanopolish-mpileup-ngmlr.vcf &

```

При картировании ридов на ngmlr выдается следущая статистика:
Done (66079 reads mapped (79.59%), 16945 reads not mapped, 91684 lines written)(elapsed: 8m, 127 r/s)
reads mapped: 66079
reads unmapped: 16945
total length: 126966508
bases mapped: 101161161
average quality: 17.7
вторичные выравнивания: 8660 (13,1%)
согласно samtols depth наибольшая глубина покрытия для trimmed-reads-20-5358nanopolish-ngmlr-depth - 241

При картировании ридов на minialign выдается следущая статистика:
reads mapped: 73294
reads unmapped: 9730
total length: 126966508
bases mapped: 111725548
average quality: 255.0
вторичные выравнивания: 2609 (3,5%)

samtols depth показывает наибольшую глубину покрытия для trimmed-reads-20-5358nanopolish-minialign-depth равную 267

В vcf-файле (выровнен minialign) 11938 строк, 29 из которых заголовок. Indel в файле 34.7% (4141 строк)

2. Poretools

```sh
poretools fastq barcode07_53_58/ > 53_58_poretools.fastq &
```

В файле столько же строк, как и в 53_58_nanopolish.fastq. Максимальное качество -71, минимальное - 34.
Последовательность обрабоки данных такая же как и в 1 пунке. По результатам NanoPlot и NanoQC отрезали 60 первых и последних нуклеотидов рида.

Наибольшее покрытие - 236

reads mapped: 61109
reads unmapped: 8082
total length: 107068107
bases mapped: 94176377  
average length: 1547
maximum length: 12223
average quality: 255.0

В vcf-файле (выровнен minialign) 14563 строк, 29 из которых заголовок. Indel в файле 32.76% (4762 строк)

При сравнении визуализации качества fastq-файлов(результат NanoPlot) двух программ для бейсколлинга видно, что при использовании nanopolish получается больше длинных ридов высокого качества, хотя разница не значительная.

Рекомендованые производителям программы, которые покупаются вместе с нанопором: Guppy (самая крутая), Albacore
Не смогли установить модули для программы: Scrappie, flappie (тоже платно), deepnano
