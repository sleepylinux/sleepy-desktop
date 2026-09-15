#pragma once

#include <QImage>

namespace sleepy {
// The daemon owns publication. This writer accepts only an empty private anonymous FD.
bool writeCapturePng(const QImage& image, int outputFd);
}
