#include <cuda_runtime.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#define random(a, b) ((a) + rand() % ((b) - (a) + 1))
#define INF 0x3f3f3f3f3f3f3f3f
#define BLOCK_SIZE 256
#define CHECK(call)                                                           \
    {                                                                         \
        const cudaError_t error = call;                                       \
        if (error != cudaSuccess) {                                           \
            printf("Error: %s:%d, ", __FILE__, __LINE__);                     \
            printf("code:%d, reson: %s\n", error, cudaGetErrorString(error)); \
            exit(-10 * error);                                                \
        }                                                                     \
    }
__host__ void initialize(int h_num_node, int *h_arc, int *h_path_node, int *h_shortLenTable) {
    srand(time(0));
    int idx = 0;
    // 数据输入 并分配内存

    // for (int i = 0; i < h_num_node; ++i) {
    //     for (int j = 0; j < h_num_node; ++j) {
    //         if (i == j)
    //             h_shortLenTable[idx] = h_arc[idx] = 0;
    //         else {
    //             h_arc[idx] = random(1, 1000) / 100.0;
    //             h_shortLenTable[idx] = h_arc[idx];
    //         }
    //     }
    // }
    int Prange = 4;
    for (int i = 0; i < h_num_node; i++) {
        for (int j = 0; j < h_num_node; j++) {
            if (i == j)
                h_shortLenTable[idx] = h_arc[idx] = 0;
            else {
                int pr = rand() % Prange;
                h_shortLenTable[idx] = h_arc[idx] = pr == 0 ? ((rand() % 997) + 1) : INF; //set edge random edge weight to random value, or to INF
            }
            h_path_node[idx] = -1;
            ++idx;
        }
    }
}
__host__ void hostCalShortTable(int h_num_node, int *h_arc, int *h_path_node, int *h_shortLenTable) {
    struct timeval start, end;
    gettimeofday(&start, NULL);
    int idx, idb, ida;
    for (int k = 0; k < h_num_node; ++k) {
        //第k个点的松弛
        for (int i = 0; i < h_num_node; ++i) {
            for (int j = 0; j < h_num_node; ++j) {
                idx = i * h_num_node + j;
                idb = i * h_num_node + k;
                ida = k * h_num_node + j;
                if (h_shortLenTable[idx] >
                    h_shortLenTable[idb] + h_shortLenTable[ida]) {
                    h_shortLenTable[idx] =
                        h_shortLenTable[idb] + h_shortLenTable[ida];
                    h_path_node[idx] = k;
                }
            }
        }
    }
    gettimeofday(&end, NULL);
    printf("CPU Time: %.6lfs\n", end.tv_usec / 1000000.0 + end.tv_sec -
                                     start.tv_usec / 1000000.0 - start.tv_sec);
}
__host__ bool checkResult(int h_num_node, int *h_path_node, int *h_shortLenTable, int *res_path_node, int *res_shortLenTable) {
    int tot = h_num_node * h_num_node;
    int idx = 0, idy = 0;
    for (int i = 0; i < tot; ++i) {
        if (h_path_node[i] != res_path_node[i] || h_shortLenTable[i] != res_shortLenTable[i]) {
            printf("Wrong Answer on %d to %d.\n", idx, idy);
            printf("Host   result: path_node[%d][%d] = %d, shortLenTable[%d][%d] = %.2f.\n", idx, idy, h_path_node[i], idx, idy, h_shortLenTable[i]);
            printf("Device result: path_node[%d][%d] = %d, shortLenTable[%d][%d] = %.2f.\n", idx, idy, res_path_node[i], idx, idy, res_shortLenTable[i]);
            return false;
        }
        ++idx;
        if (idx == h_num_node)
            idx = 0, ++idy;
    }
    puts("The results of GPU and CPU are the same.");
    return true;
}
__global__ void deviceCalBetter(int k, int d_num_node, int *d_path_node, int *d_shortLenTable) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int N = d_num_node;
    if (col >= N)
        return;
    int idx = N * blockIdx.y + col;

    __shared__ int best;
    if (threadIdx.x == 0)
        best = d_shortLenTable[N * blockIdx.y + k];
    __syncthreads();
    if (best == INF)
        return;
    int tmp_b = d_shortLenTable[k * N + col];
    if (tmp_b == INF)
        return;
    int cur = best + tmp_b;
    if (cur < d_shortLenTable[idx]) {
        d_shortLenTable[idx] = cur;
        d_path_node[idx] = k;
    }
}
__global__ void deviceCalShortTable(int k, int *d_num_node, int *d_path_node, int *d_shortLenTable) {
    unsigned int IDX = blockDim.x * blockIdx.x + threadIdx.x;
    __shared__ int N;
    N = *d_num_node;
    if (IDX >= N * N)
        return;
    //cal the i and j
    int i = IDX % N;
    int j = IDX / N;
    int idx = i * N + j;
    int idb = i * N + k;
    int ida = k * N + j;
    if (d_shortLenTable[idx] >
        d_shortLenTable[idb] + d_shortLenTable[ida]) {
        d_shortLenTable[idx] =
            d_shortLenTable[idb] + d_shortLenTable[ida];
        d_path_node[idx] = k;
    }
}
void shortestPath_floyd(int h_num_node, int *h_arc, int *h_path_node, int *h_shortLenTable) {
    int totIntBytes = h_num_node * h_num_node * sizeof(int *);
    int totintBytes = h_num_node * h_num_node * sizeof(int *);
    //设备端变量定义
    int d_num_node = h_num_node;
    int *d_arc;
    int *d_path_node;
    int *d_shortLenTable;

    cudaMalloc((void **)&d_arc, totintBytes);
    cudaMalloc((void **)&d_path_node, totIntBytes);
    cudaMalloc((void **)&d_shortLenTable, totintBytes);

    //Host To Device
    cudaMemcpy(d_arc, h_arc, totintBytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_path_node, h_path_node, totIntBytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_shortLenTable, h_shortLenTable, totintBytes, cudaMemcpyHostToDevice);
    // printf("%d %d\n", d_num_node, h_num_node);

    //git
    dim3 dimGrid((h_num_node + BLOCK_SIZE - 1) / BLOCK_SIZE, h_num_node);
    for (int k = 0; k < h_num_node; ++k) {
        deviceCalBetter<<<dimGrid, BLOCK_SIZE>>>(k, d_num_node, d_path_node, d_shortLenTable);
    }
    cudaDeviceSynchronize();

    // //分配任务
    // int calSize = h_num_node * h_num_node;
    // dim3 grid((calSize + BLOCK_SIZE - 1) / BLOCK_SIZE);

    // for (int k = 0; k < h_num_node; ++k) {
    //     deviceCalShortTable<<<grid, BLOCK_SIZE>>>(k, d_num_node, d_path_node, d_shortLenTable);
    // }
    // cudaDeviceSynchronize();

    //record and check the result
    // int *res_path_node;
    // int *res_shortLenTable;
    // res_path_node = (int *)malloc(totIntBytes);
    // res_shortLenTable = (int *)malloc(totintBytes);
    // cudaMemcpy(res_path_node, d_path_node, totIntBytes, cudaMemcpyDeviceToHost);
    // cudaMemcpy(res_shortLenTable, d_shortLenTable, totintBytes, cudaMemcpyDeviceToHost);
    // hostCalShortTable(h_num_node, h_arc, h_path_node, h_shortLenTable);
    // checkResult(h_num_node, h_path_node, h_shortLenTable, res_path_node, res_shortLenTable);
    // free(res_path_node);
    // free(res_shortLenTable);

    cudaFree(d_arc);
    cudaFree(d_path_node);
    cudaFree(d_shortLenTable);
}
__global__ void warmingup(int n) {
    unsigned int IDX = blockDim.x * blockIdx.x + threadIdx.x;
    if (IDX >= n)
        return;
}

int main(int argc, char **argv) {
    printf("%s Starting...\n", argv[0]);

    //get device information
    int dev = 0;
    cudaDeviceProp deviceProp;
    CHECK(cudaGetDeviceProperties(&deviceProp, dev));
    printf("Using Device %d: %s\n", dev, deviceProp.name);
    CHECK(cudaSetDevice(dev));

    //读文件
    //主机变量定义
    int h_num_node;       // 节点个数 70~50000
    int *h_arc;           // 邻接矩阵
    int *h_path_node;     // 最短路径
    int *h_shortLenTable; // 最短路径长度

    h_num_node = 1000;
    int totIntBytes = h_num_node * h_num_node * sizeof(int *);
    int totintBytes = h_num_node * h_num_node * sizeof(int *);
    h_arc = (int *)malloc(totintBytes);
    h_path_node = (int *)malloc(totIntBytes);
    h_shortLenTable = (int *)malloc(totintBytes);

    initialize(h_num_node, h_arc, h_path_node, h_shortLenTable);

    int calSize = h_num_node * h_num_node;
    dim3 grid((calSize + BLOCK_SIZE - 1) / BLOCK_SIZE);
    dim3 block(BLOCK_SIZE);
    warmingup<<<grid, block>>>(32);
    //初始化时间参数
    struct timeval start, end;
    gettimeofday(&start, NULL);
    //calculate on GPU
    shortestPath_floyd(h_num_node, h_arc, h_path_node, h_shortLenTable);
    //输出用时
    gettimeofday(&end, NULL);
    printf("GPU Time: %.6lfs\n", end.tv_usec / 1000000.0 + end.tv_sec -
                                     start.tv_usec / 1000000.0 - start.tv_sec);

    // hostCalShortTable(h_num_node, h_arc, h_path_node, h_shortLenTable);

    //释放内存
    free(h_arc);
    free(h_path_node);
    free(h_shortLenTable);

    cudaDeviceReset();
    return 0;
}