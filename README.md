# Parallel cyclic reduction (CUDA)
Реализация параллельного алгоритма метода циклической редукции с использованием технологии CUDA. Ограничение на размерность системы – двойка, возведённая в степень, минус один.

Реализации алгоритма тестировались на следующей конфигурации:
<img width="757" height="503" alt="{ABA4EB4F-A1BD-42CD-A7F2-6BDEE78DA2D2}" src="https://github.com/user-attachments/assets/e9724e8d-b947-438b-8805-03e09568122f" />

Для компиляции кода на CPU использовался компилятор GCC 13.1.0. 
Для компиляции кода на GPU использовался компилятор NVIDIA CUDA compiler driver NVCC для CUDA 
версии 12.4

График времени работы последовательной и параллельной реализаций:
<img width="711" height="548" alt="{E0E74023-D298-423F-8CF8-D0C731EF1F6D}" src="https://github.com/user-attachments/assets/761808b2-9cbc-47c6-bcae-384d02c190b0" />

График ускорения:
<img width="761" height="559" alt="{39D0F5F1-7B09-44A7-86BA-718B4A2DF1FC}" src="https://github.com/user-attachments/assets/973db081-b77f-4e63-9cdc-a41e0bb0772a" />

Максимальное ускорение параллельной реализации 
составило ~6,52 при решении системы из 2^23 - 1 уравнений.
