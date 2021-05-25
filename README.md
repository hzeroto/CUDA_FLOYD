## Files

`data.in` :  read the data

`data.out`: write the data

`test.cpp`: serial algorithm for floyd

**`floyd.cu`: **parallel algorithm for floyd, **main**

`make.cpp`: randomly generated data

## Running time

N（num of nodes） | GPU Time |  CPU Time  
:-:|:-:|:-:
10 | 0.000454s | 0.000007s 
100 | 0.001164s | 0.005753s 
500 | 0.015586s | 0.643502s 
1000 | 0.097510s | 5.003596s 
4000 | 3.765724s | 316.557078s 

## Device

GPU: NVIDIA Tesla K80 

CPU: Intel(R) Xeon(R) CPU E5-2680 v2 @ 2.80GHz
