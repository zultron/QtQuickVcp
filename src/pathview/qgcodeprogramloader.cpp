/****************************************************************************
**
** Copyright (C) 2014 Alexander Rössler
** License: LGPL version 2.1
**
** This file is part of QtQuickVcp.
**
** All rights reserved. This program and the accompanying materials
** are made available under the terms of the GNU Lesser General Public License
** (LGPL) version 2.1 which accompanies this distribution, and is available at
** http://www.gnu.org/licenses/lgpl-2.1.html
**
** This library is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
** Lesser General Public License for more details.
**
** Contributors:
** Alexander Rössler @ The Cool Tool GmbH <mail DOT aroessler AT gmail DOT com>
**
****************************************************************************/

#include "qgcodeprogramloader.h"

QGCodeProgramLoader::QGCodeProgramLoader(QObject *parent) :
    QObject(parent),
    m_localFilePath(""),
    m_localPath(""),
    m_remotePath(""),
    m_model(nullptr),
    m_text("")
{
}

void QGCodeProgramLoader::save(const QString &text)
{
    QString localFilePath = QUrl(m_localFilePath).toLocalFile();
    saveAs(localFilePath, text);
}

void QGCodeProgramLoader::saveAs(const QString &localFilePath, const QString &text)
{
    QFile f(localFilePath);
    if (!f.open(QFile::WriteOnly | QFile::Truncate | QFile::Text)) {
        emit savingFailed();
        return;
    }
    f.write(text.toLocal8Bit());
    f.close();

    emit savingFinished();
}

void QGCodeProgramLoader::load()
{
    if (m_model == nullptr)
    {
        emit loadingFailed();
        return;
    }

    QString localFilePath = QUrl(m_localFilePath).toLocalFile();
    QString localPath = QUrl(m_localPath).toLocalFile();
    QString remotePath = QUrl(m_remotePath).toLocalFile();
    QString remoteFilePath;

    if (localFilePath.indexOf(localPath) == 0)
    {
        remoteFilePath = QDir(remotePath).filePath(localFilePath.mid(localPath.length() + 1));
    }
    else
    {
        QFileInfo fileInfo(localFilePath);
        remoteFilePath = QDir(remotePath).filePath(fileInfo.fileName());
    }

    QFile file(localFilePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        emit loadingFailed();
        return;
    }

    m_text = QString(file.readAll());
    file.close();
    emit textChanged();

    updateModel(remoteFilePath);

    emit loadingFinished();
}

void QGCodeProgramLoader::updateModel(const QString &remoteFilePath)
{
    int lineNumber = 0;
    lineNumber = m_text.count(QLatin1Char('\n')) + 1; // +1 for the last line

    m_model->beginUpdate();
    m_model->prepareFile(remoteFilePath, lineNumber);

    QTextStream textStream(&m_text, QIODevice::ReadOnly);
    lineNumber = 0;
    QString line;
    while (textStream.readLineInto(&line))
    {
        lineNumber++;
        m_model->setData(remoteFilePath, lineNumber, line, QGCodeProgramModel::GCodeRole);

    }

    m_model->endUpdate();
}
