# Parallel cyclic reduction (CUDA)
Реализация параллельного алгоритма метода циклической редукции с использованием технологии CUDA. Ограничение на размерность системы – двойка, возведённая в степень, минус один.

Реализации алгоритма запускались на следующей конфигурации:
<table>
  <thead>
    <tr>
      <th align="left">Устройство</th>
      <th align="left">Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><b>Центральный процессор</b></td>
      <td>Intel Core i5-12450H, 8 ядер, 2.0 GHz</td>
    </tr>
    <tr>
      <td><b>Оперативная память</b></td>
      <td>16 GB DDR4, 3200 MHz</td>
    </tr>
    <tr>
      <td><b>Графический процессор</b></td>
      <td>Nvidia GeForce RTX 4050 Laptop, 2560 CUDA ядер, 1605-2370 MHz, 6 GB GDDR6</td>
    </tr>
  </tbody>
</table>

Для компиляции кода на CPU использовался компилятор GCC 13.1.0. 
Для компиляции кода на GPU использовался компилятор NVIDIA CUDA compiler driver NVCC для CUDA 
версии 12.4

График времени работы последовательной и параллельной реализаций:

<img width="600" alt="{E0E74023-D298-423F-8CF8-D0C731EF1F6D}" src="https://github.com/user-attachments/assets/761808b2-9cbc-47c6-bcae-384d02c190b0" />

График ускорения:

<img width="600" alt="{39D0F5F1-7B09-44A7-86BA-718B4A2DF1FC}" src="https://github.com/user-attachments/assets/973db081-b77f-4e63-9cdc-a41e0bb0772a" />

Максимальное ускорение параллельной реализации 
составило ~6,52 при решении системы из 2^23 - 1 уравнений.
