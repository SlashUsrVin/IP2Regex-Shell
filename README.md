# IP2Regex-Shell  
Converts an IP or an IP range to regex (works well with ipcalc)  
  
    ./ip2regex.sh "192.168.1.0" "192.168.1.255"
    
    OUTPUT: (192)\.(168)\.(1)\.([0-9]|[2-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])
  
## Regular Expression Logic  
#### Regex is built per octet and done in up to 5 parts, depending from the range to be built.  
  
#### Example 1: (Full Range)  
Input Range: 0 - 255  
Regex Output: [0-9] | [1-9][0-9] | 1[0-9][0-9] | 2[0-4][0-9] | 25[0-5]  
|    FIRST9 |     PART99    |     PART199    |      PRIOR-10TH  |      FINAL9   |  
|:-------:|:--------------:|:---------------:|:---------------:|:----------:|  
|   0 - 9   |     10 - 99      |     100 - 199     |     200 - 249     |   250 - 255  |  
|  [0-9]  |   [1-9][0-9]   |   1[0-9][0-9]   |   2[0-4][0-9]   |   25[0-5]  |  
  
#### Example 2:  
Input Range: 1 - 8  
Regex Output: [1-8]  
|    FIRST9 |     PART99    |     PART199    |      PRIOR-10TH  |      FINAL9   |  
|:-------:|:--------------:|:---------------:|:---------------:|:----------:|  
|     |           |          |          |   1 - 8  |  
|  N/A |   N/A   |   N/A   |   N/A |   [1-8]  |  

#### Example 3:  
Input Range: 1 - 45  
Regex Output:  [1-9] | [1-3][0-9] | 4[0-5]  
|    FIRST9 |     PART99    |     PART199    |      PRIOR-10TH  |      FINAL9   |  
|:-------:|:--------------:|:---------------:|:---------------:|:----------:|  
|   1 - 9   |           |        |     10 - 39     |   40 - 45  |  
|  [1-9]  |  N/A   |   N/A   |   [1-3][0-9]   |   4[0-5]  |  
  
#### Example 4:  
Input Range: 20 - 135  
Regex Output:  [1-9] | [1-3][0-9] | 4[0-5]  
|    FIRST9 |     PART99    |     PART199    |      PRIOR-10TH  |      FINAL9   |  
|:-------:|:--------------:|:---------------:|:---------------:|:----------:|  
|   20 - 29   |   30 - 99        |        |     100 - 129     |   130 - 135  |  
|  2[0-9]  |  [3-9][0-9]   |   N/A   |   1[0-2][0-9]   |   13[0-5]  |  

