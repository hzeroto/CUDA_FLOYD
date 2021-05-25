#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#include <algorithm>
using namespace std;

void hostCalShortTable(int h_num_node, float *h_arc, int *h_path_node,
                       float *h_shortLenTable) {
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
}

int main() {
    //读文件
    freopen("data.in", "r", stdin);
    freopen("data.out", "w", stdout);
    //主机变量定义
    int h_num_node;          // 节点个数 70~50000
    float *h_arc;            // 邻接矩阵
    int *h_path_node;        // 最短路径
    float *h_shortLenTable;  // 最短路径长度
    // 数据输入 并分配内存
    scanf("%d", &h_num_node);
    int totIntBytes = h_num_node * h_num_node * sizeof(int *);
    int totFloatBytes = h_num_node * h_num_node * sizeof(float *);

    h_arc = (float *)malloc(totFloatBytes);
    h_path_node = (int *)malloc(totIntBytes);
    h_shortLenTable = (float *)malloc(totFloatBytes);
    int idx;
    for (int i = 0; i < h_num_node; ++i) {
        for (int j = 0; j < h_num_node; ++j) {
            idx = i * h_num_node + j;
            scanf("%f", h_arc + idx);
            h_shortLenTable[idx] = h_arc[idx];
            h_path_node[idx] = -1;
        }
    }

    //初始化时间参数
    struct timeval start, end;
    //本地计算
    gettimeofday(&start, NULL);
    hostCalShortTable(h_num_node, h_arc, h_path_node, h_shortLenTable);
    gettimeofday(&end, NULL);
    printf("CPU Time: %.6lfs\n", end.tv_usec / 1000000.0 + end.tv_sec -
                                     start.tv_usec / 1000000.0 - start.tv_sec);
    for (int i = 0; i < h_num_node; ++i) {
        for (int j = 0; j < h_num_node; ++j) {
            idx = i * h_num_node + j;
            printf("%d ", h_path_node[idx]);
        }
        puts(" ");
    }
    puts("");
    for (int i = 0; i < h_num_node; ++i) {
        for (int j = 0; j < h_num_node; ++j) {
            idx = i * h_num_node + j;
            printf("%.2f ", h_shortLenTable[idx]);
        }
        puts(" ");
    }
    //释放内存
    free(h_arc);
    free(h_path_node);
    free(h_shortLenTable);

    return 0;
}